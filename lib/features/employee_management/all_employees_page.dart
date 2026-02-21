import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'employee_details_page.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _bg       = Color(0xFFF7F9FC);
const Color _primary  = Color(0xFF2563EB);
const Color _primaryDk= Color(0xFF1E3A8A);
const Color _card     = Color(0xFFFFFFFF);
const Color _border   = Color(0x14000000);
const Color _fg       = Color(0xFF0F172A);
const Color _muted    = Color(0xFF94A3B8);

class AllEmployeesPage extends StatefulWidget {
  const AllEmployeesPage({super.key});
  @override
  State<AllEmployeesPage> createState() => _AllEmployeesPageState();
}

class _AllEmployeesPageState extends State<AllEmployeesPage> {
  String _cid    = '';
  String _search = '';
  String? _filterDept;

  static const _depts = [
    _Dept('All',       null,        Icons.people_alt_rounded),
    _Dept('HR',        'hr',        Icons.groups_rounded),
    _Dept('Marketing', 'marketing', Icons.campaign_rounded),
    _Dept('Factory',   'factory',   Icons.factory_rounded),
    _Dept('Admin',     'admin',     Icons.admin_panel_settings_rounded),
    _Dept('R&D',       'rnd',       Icons.science_rounded),
  ];

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _primaryDk,
        foregroundColor: Colors.white,
        title: Text('Employees',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 17)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primaryDk],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (_cid.isNotEmpty)
            StreamBuilder<QuerySnapshot>(
              stream: DB.colSync(_cid, C.users).snapshots(),
              builder: (_, s) {
                final n = s.data?.docs.length ?? 0;
                return Center(
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.18),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('$n total',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                );
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
              style: GoogleFonts.inter(fontSize: 14, color: _fg),
              decoration: InputDecoration(
                hintText: 'Search by name, email or ID…',
                hintStyle: GoogleFonts.inter(color: _muted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _muted),
                filled: true,
                fillColor: _card,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary, width: 1.5)),
              ),
            ),
          ),

          // ── Department filter chips ────────────────────────────────────────
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _depts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d        = _depts[i];
                final selected = _filterDept == d.key;
                return GestureDetector(
                  onTap: () => setState(() => _filterDept = d.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? _primary : _card,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                          color: selected ? _primary : _border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(d.icon,
                          size: 14,
                          color: selected ? Colors.white : _muted),
                      const SizedBox(width: 5),
                      Text(d.label,
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected ? Colors.white : _fg)),
                    ]),
                  ),
                );
              },
            ),
          ),

          // ── Employee list ──────────────────────────────────────────────────
          Expanded(
            child: _cid.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _EmployeeList(
                    cid: _cid, dept: _filterDept, search: _search),
          ),
        ],
      ),
    );
  }
}

// ── Employee list ─────────────────────────────────────────────────────────────
class _EmployeeList extends StatelessWidget {
  final String cid;
  final String? dept;
  final String search;
  const _EmployeeList({required this.cid, required this.dept, required this.search});

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> q = DB.colSync(cid, C.users).orderBy('fullName');
    if (dept != null) q = q.where('department', isEqualTo: dept);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: q.snapshots(),
      builder: (_, snap) {
        if (snap.hasError) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: Color(0xFFDC2626)),
              const SizedBox(height: 10),
              Text('Could not load employees',
                  style: GoogleFonts.inter(color: _muted, fontSize: 14)),
            ]),
          );
        }
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: _primary));
        }

        var docs = snap.data!.docs;
        if (search.isNotEmpty) {
          docs = docs.where((d) {
            final m     = d.data();
            final name  = (m['fullName']    ?? '').toString().toLowerCase();
            final email = (m['officeEmail'] ?? m['email'] ?? '').toString().toLowerCase();
            final eid   = (m['employeeId']  ?? '').toString().toLowerCase();
            return name.contains(search) ||
                email.contains(search) ||
                eid.contains(search);
          }).toList();
        }

        if (docs.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: _primary.withOpacity(.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.person_search_rounded,
                    size: 30, color: _primary),
              ),
              const SizedBox(height: 14),
              Text('No employees found',
                  style: GoogleFonts.inter(
                      color: _fg,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 4),
              Text('Try a different filter or search term.',
                  style: GoogleFonts.inter(color: _muted, fontSize: 13)),
            ]),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d        = docs[i];
            final m        = d.data();
            final name     = (m['fullName'] as String?)?.trim().isNotEmpty == true
                ? m['fullName'] as String
                : 'Unnamed';
            final email    = (m['officeEmail'] ?? m['email'] ?? '') as String;
            final deptRaw  = (m['department']  ?? '') as String;
            final eid      = (m['employeeId']  ?? d.id) as String;
            final photoUrl = (m['profilePhotoUrl'] ?? '') as String;
            final isHead   = (m['isHead'] ?? false) == true;

            return _EmpTile(
              name: name,
              email: email,
              deptRaw: deptRaw,
              employeeId: eid,
              photoUrl: photoUrl,
              isHead: isHead,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EmployeeDetailsPage(
                      uid: d.id, userEmail: email, employeeId: eid),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Employee tile ─────────────────────────────────────────────────────────────
class _EmpTile extends StatelessWidget {
  final String name, email, deptRaw, employeeId, photoUrl;
  final bool isHead;
  final VoidCallback onTap;

  const _EmpTile({
    required this.name,
    required this.email,
    required this.deptRaw,
    required this.employeeId,
    required this.photoUrl,
    required this.isHead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final deptColor = _deptColor(deptRaw);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: deptColor.withOpacity(.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: photoUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(photoUrl, fit: BoxFit.cover),
                          )
                        : Center(
                            child: Text(
                              _initials(name),
                              style: GoogleFonts.inter(
                                  color: deptColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15),
                            ),
                          ),
                  ),
                  if (isHead)
                    Positioned(
                      right: -1, bottom: -1,
                      child: Container(
                        width: 16, height: 16,
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          shape: BoxShape.circle,
                          border: Border.all(color: _card, width: 1.5),
                        ),
                        child: const Icon(Icons.check_rounded,
                            size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: _fg)),
                    const SizedBox(height: 3),
                    Text(
                      email.isNotEmpty ? email : 'No email',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: _muted),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      _Chip(
                        label: deptRaw.isEmpty
                            ? '—'
                            : deptRaw[0].toUpperCase() + deptRaw.substring(1),
                        color: deptColor,
                      ),
                      const SizedBox(width: 6),
                      _Chip(label: employeeId, color: _muted, muted: true),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded, color: _muted, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final bool muted;
  const _Chip({required this.label, required this.color, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF1F5F9) : color.withOpacity(.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: muted ? _muted : color)),
    );
  }
}

// ── Public EmployeeList (used by other screens) ───────────────────────────────
class EmployeeList extends StatefulWidget {
  final String? department;
  const EmployeeList({super.key, this.department});
  @override
  State<EmployeeList> createState() => _EmployeeListState();
}

class _EmployeeListState extends State<EmployeeList> {
  String _cid = '';
  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }
    return _EmployeeList(cid: _cid, dept: widget.department, search: '');
  }
}

// ── Models ────────────────────────────────────────────────────────────────────
class _Dept {
  final String label;
  final String? key;
  final IconData icon;
  const _Dept(this.label, this.key, this.icon);
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

Color _deptColor(String d) {
  switch (d) {
    case 'admin':     return const Color(0xFF7C3AED);
    case 'hr':        return const Color(0xFF2563EB);
    case 'marketing': return const Color(0xFF16A34A);
    case 'factory':   return const Color(0xFFF97316);
    case 'rnd':       return const Color(0xFFDC2626);
    default:          return _muted;
  }
}
