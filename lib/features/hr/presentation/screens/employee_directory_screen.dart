import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/theme/app_fonts.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _primaryGreen = Color(0xFF0A4128);
const _backgroundColor = Color(0xFFF4F7F6);
const _surfaceColor = Color(0xFFFFFFFF);

// ─────────────────────────────────────────────────────────────────────────────
class EmployeeDirectoryScreen extends StatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  State<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  String _cid = '';
  String _searchQuery = '';
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadCid();
  }

  Future<void> _loadCid() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (mounted) setState(() => _cid = id ?? '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: _SearchBar(onChanged: (val) => setState(() => _searchQuery = val)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    _FilterTabs(
                      activeFilter: _activeFilter,
                      onChanged: (val) => setState(() => _activeFilter = val),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _EmployeeList(
                        cid: _cid,
                        searchQuery: _searchQuery,
                        filter: _activeFilter,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}



class _SearchBar extends StatelessWidget {
  final Function(String) onChanged;
  const _SearchBar({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search roster...',
          hintStyle: AppFonts.banglaBody(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _FilterTabs extends StatelessWidget {
  final String activeFilter;
  final Function(String) onChanged;
  const _FilterTabs({required this.activeFilter, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'HR', 'Marketing', 'Factory', 'Admin'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: filters.map((f) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: GestureDetector(
            onTap: () => onChanged(f),
            child: AnimatedContainer(
              duration: 200.ms,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: activeFilter == f ? _primaryGreen : _backgroundColor,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  if (activeFilter == f) const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 14),
                  if (activeFilter == f) const SizedBox(width: 8),
                  Text(
                    f,
                    style: AppFonts.banglaHeading(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: activeFilter == f ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  final String cid, searchQuery, filter;
  const _EmployeeList({required this.cid, required this.searchQuery, required this.filter});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: DB.colSync(cid, C.users).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] ?? '').toString().toLowerCase();
          final matchesSearch = name.contains(searchQuery.toLowerCase());
          final matchesFilter = filter == 'All' || (data['role'] ?? '').toString().contains(filter);
          return matchesSearch && matchesFilter;
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          itemCount: docs.length,
          itemBuilder: (context, i) => _RosterCard(data: docs[i].data() as Map<String, dynamic>),
        );
      },
    );
  }
}

class _RosterCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RosterCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] ?? 'Unnamed';
    final role = data['role'] ?? 'Employee';
    final email = data['email'] ?? 'No email provided';
    final dept = (data['role'] ?? 'GENERAL').toString().split(' ').first.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9).withOpacity(0.5),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(right: -10, top: 0, bottom: 0, child: CustomPaint(size: const Size(120, double.infinity), painter: _HexPainter())),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white,
                          child: Text(name[0], style: AppFonts.banglaHeading(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryGreen)),
                        ),
                        Positioned(
                          bottom: -2,
                          right: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(4)),
                            child: Text('PRO', style: AppFonts.banglaHeading(color: Color(0xFFFBDB4C), fontSize: 8, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('88', style: AppFonts.banglaData(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), height: 1)),
                        Text('OVR', style: AppFonts.banglaHeading(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[500])),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(name, style: AppFonts.banglaHeading(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                Text(role, style: AppFonts.banglaHeading(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                Text(email, style: AppFonts.banglaBody(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _Tag(label: dept, icon: Icons.work_outline_rounded),
                    const SizedBox(width: 8),
                    _Tag(label: 'UIGB', isOutline: true),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatBox(value: '92', label: 'PERF'),
                    _StatBox(value: '3 YRS', label: 'TENURE'),
                    _StatBox(value: '24', label: 'PROJE'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideX(begin: 0.1, end: 0);
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isOutline;
  const _Tag({required this.label, this.icon, this.isOutline = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOutline ? Colors.transparent : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(8),
        border: isOutline ? Border.all(color: Colors.grey.withOpacity(0.2)) : null,
      ),
      child: Row(
        children: [
          if (icon != null) Icon(icon, size: 12, color: const Color(0xFF059669)),
          if (icon != null) const SizedBox(width: 4),
          Text(label, style: AppFonts.banglaHeading(fontSize: 9, fontWeight: FontWeight.w900, color: isOutline ? Colors.grey[600] : Color(0xFF059669))),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value, style: AppFonts.banglaData(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF111827))),
          Text(label, style: AppFonts.banglaHeading(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey[400])),
        ],
      ),
    );
  }
}

class _HexPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width * 0.5, 0);
    path.lineTo(size.width, size.height * 0.2);
    path.lineTo(size.width, size.height * 0.8);
    path.lineTo(size.width * 0.5, size.height);
    path.lineTo(0, size.height * 0.8);
    path.lineTo(0, size.height * 0.2);
    path.close();

    canvas.drawPath(path, paint);
    
    // Nested hex
    paint.color = Colors.grey.withOpacity(0.04);
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.5), 40, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
