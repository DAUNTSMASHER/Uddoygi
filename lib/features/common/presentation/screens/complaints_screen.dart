import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/common/complaints/new_complaint.dart';
import 'package:uddoygi/features/common/complaints/all_complaint.dart';
import 'package:uddoygi/features/common/complaints/punishment_reward.dart';
import 'package:uddoygi/features/common/complaints/pending_complaint.dart';
import 'package:uddoygi/features/common/complaints/complaint_actions.dart';

/// ===== Palette / Sizes =====
const _brandBlue = Colors.indigo;

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  String _role = "user";
  String _userEmail = "";
  String _userName = "";
  bool _loading = true;

  int _index = 0; // bottom nav index

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final session = await LocalStorageService.getSession();
    String role = (session?['role'] ?? "unknown").toLowerCase();
    final email = (session?['email'] ?? "").toString();
    final name = (session?['name'] ?? email).toString();

    if (role == "unknown" && email.isNotEmpty) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (userDoc.docs.isNotEmpty) {
        role = (userDoc.docs.first.data()['department'] ?? 'user').toLowerCase();
        await LocalStorageService.setSessionField('role', role);
      }
    }

    setState(() {
      _role = role;
      _userEmail = email;
      _userName = name;
      _loading = false;
    });
  }

  bool get isHrOrAdmin => _role == "admin" || _role == "hr";

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // NOTE: NewComplaintScreen / AllComplaintScreen / PunishmentRewardScreen
    // already have their own AppBars, so we do NOT add one here.
    final pages = <Widget>[
      NewComplaintScreen(userEmail: _userEmail),
      AllComplaintScreen(userEmail: _userEmail, userName: _userName),
      PunishmentRewardScreen(userEmail: _userEmail),
      _AgainstMeScaffold(
        userEmail: _userEmail,
        userName: _userName,
        role: _role,
      ),
      if (isHrOrAdmin)
        _ResolutionScaffold(
          userEmail: _userEmail,
          userName: _userName,
          role: _role,
        ),
    ];

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(icon: Icon(Icons.add), label: 'New'),
      const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Previous'),
      const BottomNavigationBarItem(icon: Icon(Icons.workspace_premium), label: 'Reward'),
      const BottomNavigationBarItem(icon: Icon(Icons.warning_amber_rounded), label: 'Against Me'),
      if (isHrOrAdmin)
        const BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Resolution'),
    ];

    // Guard if role flips while open
    final maxIndex = pages.length - 1;
    if (_index > maxIndex) _index = maxIndex;

    return Scaffold(
      backgroundColor: Colors.white,
      // ⬇️ NO TOP APP BAR HERE (prevents the duplicate header)
      body: pages[_index],
      bottomNavigationBar: SafeArea(
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          type: BottomNavigationBarType.fixed,
          backgroundColor: _brandBlue,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          items: items,
        ),
      ),
    );
  }
}

/* ======================= Against Me (with its own AppBar) ======================= */

class _AgainstMeScaffold extends StatelessWidget {
  final String userEmail;
  final String userName;
  final String role;
  const _AgainstMeScaffold({
    required this.userEmail,
    required this.userName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaints Against Me', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _ComplaintsAgainstMeTab(userEmail: userEmail, userName: userName, role: role),
    );
  }
}

class _ComplaintsAgainstMeTab extends StatelessWidget {
  final String userEmail;
  final String userName;
  final String role;

  const _ComplaintsAgainstMeTab({
    required this.userEmail,
    required this.userName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .where('againstEmail', isEqualTo: userEmail)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No complaints filed against you."));
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final subject = (data['subject'] ?? '(No Subject)').toString();
            final message = (data['message'] ?? '').toString();
            final submittedBy = (data['submittedByName'] ?? 'Someone').toString();
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                title: Text(
                  subject,
                  style: const TextStyle(color: _brandBlue, fontWeight: FontWeight.w700),
                ),
                subtitle: Text("Filed by: $submittedBy\n$message"),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }
}

/* ======================= Resolution (own Scaffold + inner tabs) ======================= */

class _ResolutionScaffold extends StatefulWidget {
  final String role;
  final String userEmail;
  final String userName;

  const _ResolutionScaffold({
    required this.role,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<_ResolutionScaffold> createState() => _ResolutionScaffoldState();
}

class _ResolutionScaffoldState extends State<_ResolutionScaffold>
    with TickerProviderStateMixin {
  late TabController _resTabController;

  bool get isHrOrAdmin => widget.role == "admin" || widget.role == "hr";

  @override
  void initState() {
    super.initState();
    _resTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _resTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isHrOrAdmin) {
      return const Scaffold(
        body: Center(
          child: Text(
            "Unauthorized.\nOnly Admin and HR can access complaint resolution.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Resolution', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: _brandBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _resTabController,
          isScrollable: true,
          labelPadding: const EdgeInsets.symmetric(horizontal: 12.0),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          tabs: const [
            Tab(icon: Icon(Icons.assignment_late), text: "Pending Complaints"),
            Tab(icon: Icon(Icons.build), text: "All Actions"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _resTabController,
        children: [
          PendingComplaintScreen(
            userEmail: widget.userEmail,
            isCEO: widget.role == "ceo",
          ),
          _AllComplaintActionsList(
            userName: widget.userName,
            userRole: widget.role,
          ),
        ],
      ),
    );
  }
}

class _AllComplaintActionsList extends StatelessWidget {
  final String userName;
  final String userRole;
  const _AllComplaintActionsList({
    required this.userName,
    required this.userRole,
  });

  bool get isHrOrAdmin => userRole == "admin" || userRole == "hr";

  @override
  Widget build(BuildContext context) {
    if (!isHrOrAdmin) {
      return const Center(
        child: Text(
          "Unauthorized.\nOnly Admin and HR can access complaint actions.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('complaints')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No complaints found."));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final subject = (data['subject'] ?? '(No subject)').toString();
            final id = docs[i].id;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              child: ListTile(
                title: Text(
                  subject,
                  style: const TextStyle(color: _brandBlue, fontWeight: FontWeight.w700),
                ),
                subtitle: Text("Status: ${(data['status'] ?? '').toString()}"),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: _brandBlue),
                onTap: () {
                  if (isHrOrAdmin) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ComplaintActionsScreen(
                          complaintId: id,
                          userName: userName,
                          userRole: userRole,
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          },
        );
      },
    );
  }
}
