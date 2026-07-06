import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/features/attendance/admin_detail_view.dart';
import 'package:uddoygi/features/attendance/user_attendance_view.dart';
import 'package:uddoygi/theme/app_fonts.dart';

class FactoryAttendanceScreen extends StatelessWidget {
  const FactoryAttendanceScreen({super.key});

  void _openMyAttendance(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null || user.email == null) {
      _showError(context, "⚠️ ব্যবহারকারী লগইন করেননি।");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UserAttendanceView(), // no params needed now
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('কারখানার উপস্থিতি', style: AppFonts.banglaBody(color: Colors.white, fontWeight: FontWeight.w800)),
        backgroundColor: const Color(0xFF40062D),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(20),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _AttendanceOptionCard(
            title: 'কর্মীর উপস্থিতি',
            icon: Icons.people_alt,
            color: Colors.blueGrey,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminDetailView()),
              );
            },
          ),
          _AttendanceOptionCard(
            title: 'আমার উপস্থিতি',
            icon: Icons.person_pin_circle,
            color: const Color(0xFF40062D),
            onTap: () => _openMyAttendance(context),
          ),
        ],
      ),
    );
  }
}

class _AttendanceOptionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AttendanceOptionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              AutoSizeText(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                minFontSize: 11,
                stepGranularity: 0.5,
                style: AppFonts.banglaBody(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
