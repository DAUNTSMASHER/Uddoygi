import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/services/admin_api_service.dart' as admin_api;

class AddEmployeePage extends StatefulWidget {
  const AddEmployeePage({super.key});

  @override
  State<AddEmployeePage> createState() => _AddEmployeePageState();
}

class _AddEmployeePageState extends State<AddEmployeePage>
    with SingleTickerProviderStateMixin {
  // Firebase
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  // Forms
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _newPassCtl = TextEditingController();
  final _confirmPassCtl = TextEditingController();

  bool _loading = false;
  String? _addedByEmail;

  // Palette (match dashboard)
  static const Color _deepPurple = Color(0xFF5B0A98);
  static const Color _accentPurple = Color(0xFF6911AC);
  static const Color _panelTint = Color(0xFFF1E8FF);

  final List<String> _departments = const ['admin', 'hr', 'marketing', 'factory'];

  // Add tab
  String _addDepartment = 'marketing';

  // Reset tab
  String _recoverDepartment = 'marketing';
  String? _selectedEmployeeId; // <- stable dropdown value (fixes assertion)
  _Emp? _selectedEmployee;     // cached object for dialogs

  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _loadSession();
  }

  @override
  void dispose() {
    _idController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _newPassCtl.dispose();
    _confirmPassCtl.dispose();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    if (!mounted) return;
    setState(() => _addedByEmail = (session?['email'] as String?) ?? _auth.currentUser?.email);
  }

  // Parse digits from IDs like "EMP-00123" -> 123
  int? _parseIdNum(String s) {
    final digits = RegExp(r'\d+').allMatches(s).map((m) => m.group(0)).join();
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }

  // =========================
  // ADD EMPLOYEE
  // =========================
  Future<void> _submitAdd() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Confirm Add Employee'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReviewRow('Added by', _addedByEmail ?? 'Unknown'),
            _buildReviewRow('Employee ID', _idController.text.trim()),
            _buildReviewRow('Email', _emailController.text.trim()),
            _buildReviewRow('Department', _addDepartment),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _deepPurple),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      final idText = _idController.text.trim();
      final idNum = _parseIdNum(idText);
      final email = _emailController.text.trim();

      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // Write both email fields to align with AllEmployeesPage
      await _firestore.collection('users').doc(cred.user!.uid).set({
        'employeeId': idText,
        'employeeIdNum': idNum, // numeric mirror for ordering if needed
        'email': email,          // keep existing schema happy
        'officeEmail': email,    // <- matches AllEmployeesPage
        'department': _addDepartment,
        'addedBy': _addedByEmail,
        'fullName': 'Unnamed',   // avoid nulls in list screens
        'isHead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Success'),
          content: const Text('Employee added successfully.'),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _deepPurple),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      _idController.clear();
      _emailController.clear();
      _passwordController.clear();
      // No manual "last ID" fetch needed anymore; banner is stream-based.
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // =========================
  // RESET PASSWORD (ADMIN)
  // =========================
  Future<void> _setPasswordForEmployee() async {
    if (_selectedEmployeeId == null || _selectedEmployee == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select an employee.')));
      return;
    }
    final newPass = _newPassCtl.text.trim();
    final confirm = _confirmPassCtl.text.trim();
    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New password must be at least 6 characters.')),
      );
      return;
    }
    if (newPass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match.')),
      );
      return;
    }

    final adminPassword = await _promptAdminPassword();
    if (adminPassword == null) return;

    setState(() => _loading = true);
    try {
      final current = _auth.currentUser;
      final adminEmail = current?.email ?? _addedByEmail;
      if (current == null || adminEmail == null) {
        throw FirebaseAuthException(code: 'no-admin', message: 'Admin session not found.');
      }

      final cred = EmailAuthProvider.credential(email: adminEmail, password: adminPassword);
      await current.reauthenticateWithCredential(cred); // throws on mismatch

      await admin_api.adminSetPassword(
        uid: _selectedEmployeeId,
        newPassword: newPass,
      );


      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Password Updated'),
          content: Text(
            'Thank you for your patience.\n\n'
                'The new updated password for ${_selectedEmployee!.emailShown} is:\n\n'
                '$newPass',
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _deepPurple),
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      _newPassCtl.clear();
      _confirmPassCtl.clear();
    } on FirebaseAuthException {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Update Blocked'),
          content: const Text(
            'Sorry, you cannot update the password because your admin password did not match.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to set password: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _promptAdminPassword() async {
    final ctl = TextEditingController();
    bool obscure = true;
    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setStateSB) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text('Confirm as Admin'),
          content: TextField(
            controller: ctl,
            obscureText: obscure,
            decoration: InputDecoration(
              labelText: 'Enter your admin password',
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setStateSB(() => obscure = !obscure),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _deepPurple),
              onPressed: () => Navigator.pop(ctx, ctl.text),
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );
  }

  // =========================
  // UI helpers
  // =========================
  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.w800, color: _deepPurple)),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _deepPurple),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _deepPurple),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _deepPurple, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return '${d.inSeconds}s ago';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    final weeks = (d.inDays / 7).floor();
    if (weeks < 5) return '${weeks}w ago';
    return DateFormat('yMMMd').format(t);
  }

  // =========================
  // Build
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBar(
        title: const Text('Add / Reset Password', style: TextStyle(color: Colors.white)),
        backgroundColor: _deepPurple,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Material(
            color: _deepPurple, // visual separation from appbar
            elevation: 2,
            child: TabBar(
              controller: _tab,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Add New'),
                Tab(text: 'Reset Password'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ===== Tab 1: ADD NEW =====
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionFrame(
                title: 'Add New Employee',
                gradientA: _deepPurple,
                gradientB: _accentPurple,
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _idController,
                        decoration: _inputDecoration('Employee ID'),
                        validator: (v) => (v != null && v.trim().isNotEmpty) ? null : 'Enter an Employee ID',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        decoration: _inputDecoration('Email / Username'),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => v != null && v.contains('@') ? null : 'Enter a valid email',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        decoration: _inputDecoration('Password'),
                        obscureText: true,
                        validator: (v) => (v != null && v.length >= 6) ? null : 'Min 6 characters',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _addDepartment,
                        isExpanded: true,
                        decoration: _inputDecoration('Department'),
                        items: _departments
                            .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text(d.toUpperCase(), style: const TextStyle(color: _deepPurple)),
                        ))
                            .toList(),
                        onChanged: (v) => setState(() => _addDepartment = v!),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: _deepPurple),
                          onPressed: _loading ? null : _submitAdd,
                          child: _loading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Submit', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Live "Last added ID"
              // ===== Last Added + Recently Added (single stream; hide pending serverTimestamp) =====
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore
                    .collection('users')
                    .orderBy('createdAt', descending: true)
                    .limit(12) // a bit more headroom in case some are pending
                    .snapshots(),
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const LinearProgressIndicator();
                  }

                  final all = snap.data?.docs ?? [];

                  // Keep only docs that already have a real createdAt from server
                  bool hasTs(Map<String, dynamic> m) => m['createdAt'] is Timestamp || m['createdAt'] is DateTime;
                  final withTs = all.where((d) => hasTs(d.data())).toList();

                  if (withTs.isEmpty) {
                    return _SectionFrame(
                      title: 'Last Added',
                      gradientA: _accentPurple,
                      gradientB: _deepPurple,
                      child: const Text('No employees yet.'),
                    );
                  }

                  DateTime? _asDate(dynamic v) =>
                      v is Timestamp ? v.toDate() : (v is DateTime ? v : null);
                  String _when(Map<String, dynamic> m) {
                    final dt = _asDate(m['createdAt']);
                    return dt != null ? _timeAgo(dt) : 'just now';
                  }

                  // Header = most recent with a real timestamp
                  final lastDoc = withTs.first;
                  final last = lastDoc.data();
                  final lastId = (last['employeeId'] ?? '—').toString();
                  final lastEmail = (last['officeEmail'] ?? last['email'] ?? '—').toString();
                  final lastWhen = _when(last);

                  // Recent list = the rest with real timestamps (exclude the header)
                  final recent = withTs.skip(1).take(6).toList();

                  String _dept(Map<String, dynamic> m) {
                    final d = (m['department'] ?? '').toString();
                    return d.isEmpty ? '—' : d.toUpperCase();
                  }

                  return Column(
                    children: [
                      _SectionFrame(
                        title: 'Last Added',
                        gradientA: _accentPurple,
                        gradientB: _deepPurple,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x22000000)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.badge, color: _deepPurple),
                              const SizedBox(width: 10),
                              Expanded(child: Text('Last added employee ID is $lastId  •  $lastEmail')),
                              const SizedBox(width: 8),
                              Text(lastWhen, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionFrame(
                        title: 'Recently Added',
                        gradientA: _accentPurple,
                        gradientB: _deepPurple,
                        child: recent.isEmpty
                            ? const Text('No more recent employees.')
                            : Column(
                          children: recent.map((d) {
                            final m = d.data();
                            final id = (m['employeeId'] ?? '').toString();
                            final email = (m['officeEmail'] ?? m['email'] ?? '').toString();
                            final dept = _dept(m);
                            final when = _when(m);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0x22000000)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.badge, color: _deepPurple),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text('$id  •  $email  •  $dept',
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(when, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  );
                },
              ),

            ],
          ),

          // ===== Tab 2: RESET PASSWORD =====
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionFrame(
                title: 'Reset Password',
                gradientA: _accentPurple,
                gradientB: _deepPurple,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _recoverDepartment,
                            isExpanded: true,
                            decoration: _inputDecoration('Select Department'),
                            items: _departments
                                .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(d.toUpperCase(),
                                  style: const TextStyle(color: _deepPurple)),
                            ))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setState(() {
                                _recoverDepartment = v;
                                _selectedEmployeeId = null;
                                _selectedEmployee = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Clear selection',
                          onPressed: () => setState(() {
                            _selectedEmployeeId = null;
                            _selectedEmployee = null;
                          }),
                          icon: const Icon(Icons.clear),
                          color: _deepPurple,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Employees stream (no custom order to avoid index requirement)
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _firestore
                          .collection('users')
                          .where('department', isEqualTo: _recoverDepartment)
                          .snapshots(),
                      builder: (ctx, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const LinearProgressIndicator();
                        }
                        if (snap.hasError) {
                          return _errorBox('Failed to load employees: ${snap.error}');
                        }
                        final docs = snap.data?.docs ?? [];

                        final items = docs.map((d) {
                          final m = d.data();
                          return _Emp(
                            uid: d.id,
                            employeeId: (m['employeeId'] ?? '').toString(),
                            fullName: (m['fullName'] ?? 'Unnamed').toString(),
                            emailShown: (m['officeEmail'] ?? m['email'] ?? '').toString(),
                            department: (m['department'] ?? '').toString(),
                            isHead: (m['isHead'] ?? false) == true,
                          );
                        }).toList();

                        // Keep selected if still present
                        if (_selectedEmployeeId != null &&
                            !items.any((e) => e.uid == _selectedEmployeeId)) {
                          _selectedEmployeeId = null;
                          _selectedEmployee = null;
                        }

                        if (items.isEmpty) {
                          return _infoBox('No employees found in this department.');
                        }

                        // Map id -> emp for quick lookup on change
                        final byId = {for (final e in items) e.uid: e};

                        return SizedBox(
                          height: 64, // guarantees layout for InputDecorator
                          child: DropdownButtonFormField<String>(
                            value: _selectedEmployeeId,
                            isExpanded: true,
                            decoration: _inputDecoration('Select Employee'),
                            items: items.map((e) {
                              return DropdownMenuItem<String>(
                                value: e.uid,
                                child: Row(
                                  children: [
                                    const Icon(Icons.person, color: _deepPurple),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${e.employeeId} — ${e.emailShown.isEmpty ? e.fullName : e.emailShown}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (e.isHead)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 6),
                                        child: Icon(Icons.verified, size: 18, color: Colors.green),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (id) {
                              setState(() {
                                _selectedEmployeeId = id;
                                _selectedEmployee =
                                id == null ? null : byId[id];
                              });
                            },
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),
                    TextField(
                      controller: _newPassCtl,
                      obscureText: true,
                      decoration: _inputDecoration('New Password'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPassCtl,
                      obscureText: true,
                      decoration: _inputDecoration('Confirm New Password'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 48,
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _deepPurple,
                          disabledBackgroundColor: _deepPurple.withOpacity(.4),
                        ),
                        onPressed: _loading ? null : _setPasswordForEmployee,
                        icon: _loading
                            ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Icon(Icons.lock_reset, color: Colors.white),
                        label: const Text('Update Password Now', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your password is required only to confirm this action.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ======================== SECTION FRAME ======================== */

class _SectionFrame extends StatelessWidget {
  const _SectionFrame({
    required this.title,
    required this.child,
    required this.gradientA,
    required this.gradientB,
    this.bodyTint = _panelTint,
  });

  final String title;
  final Widget child;
  final Color gradientA;
  final Color gradientB;
  final Color bodyTint;

  static const Color _panelTint = Color(0xFFF1E8FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [gradientA, gradientB],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Container(
          decoration: BoxDecoration(
            color: bodyTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: gradientA.withOpacity(.25), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: gradientA,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .2,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/* ======================== MODELS & helpers ======================== */

class _Emp {
  final String uid;
  final String employeeId;
  final String fullName;
  final String emailShown;
  final String department;
  final bool isHead;

  _Emp({
    required this.uid,
    required this.employeeId,
    required this.fullName,
    required this.emailShown,
    required this.department,
    required this.isHead,
  });

  String get email => emailShown;
}

Widget _infoBox(String msg) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    border: Border.all(color: Color(0xFF5B0A98)),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(msg),
);

Widget _errorBox(String msg) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    border: Border.all(color: Colors.redAccent),
    borderRadius: BorderRadius.circular(8),
  ),
  child: Text(msg, style: const TextStyle(color: Colors.red)),
);
