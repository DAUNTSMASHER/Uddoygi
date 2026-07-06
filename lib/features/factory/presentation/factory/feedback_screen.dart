// lib/features/factory/presentation/factory/feedback_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/theme/app_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

class FeedbackScreen extends StatefulWidget {
  final String orderId;
  const FeedbackScreen({Key? key, required this.orderId}) : super(key: key);

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  String _cid = '';
  int _selectedRating = 0; // 1 to 5
  final TextEditingController _reportController = TextEditingController();
  bool _isUrgent = false;

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted && id != null) setState(() => _cid = id);
    });
  }

  @override
  void dispose() {
    _reportController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_cid.isEmpty || _selectedRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a rating before submitting.')));
      return;
    }

    try {
      final ref = DB.colSync(_cid, C.notifications).doc(); // Or a separate feedback collection
      await ref.set({
        'type': 'work_order_feedback',
        'refId': widget.orderId,
        'rating': _selectedRating,
        'report': _reportController.text.trim(),
        'urgent': _isUrgent,
        'timestamp': Timestamp.now(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feedback submitted successfully!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to submit feedback: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf7f9ff),
      appBar: AppBar(
        backgroundColor: const Color(0xFF94001a),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Icon(Icons.factory, color: Colors.white),
            const SizedBox(width: 8),
            Text('Industrial Velocity', style: AppFonts.banglaHeading(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.account_circle, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Work Order Feedback', style: AppFonts.banglaHeading(fontSize: 24, fontWeight: FontWeight.w700, color: Color(0xFF161c22))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Order ID: ', style: AppFonts.banglaBody(fontSize: 14, color: Color(0xFF5a403f))),
                  Text('#${widget.orderId}', style: AppFonts.banglaData(fontSize: 14, color: Color(0xFF94001a))),
                ],
              ),
              const SizedBox(height: 24),
              _buildRatingSection(),
              const SizedBox(height: 24),
              _buildDetailedReport(),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitFeedback,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6a000f),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 2,
                  ),
                  child: Text('SUBMIT REPORT', style: AppFonts.banglaHeading(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 1.0)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFe2bebc)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Overall Satisfaction', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF161c22))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRatingIcon(1, Icons.sentiment_very_dissatisfied, 'Poor'),
              _buildRatingIcon(2, Icons.sentiment_dissatisfied, 'Fair'),
              _buildRatingIcon(3, Icons.sentiment_neutral, 'Good'),
              _buildRatingIcon(4, Icons.sentiment_satisfied, 'Very Good'),
              _buildRatingIcon(5, Icons.sentiment_very_satisfied, 'Excellent'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRatingIcon(int rating, IconData icon, String label) {
    final isSelected = _selectedRating == rating;
    final color = isSelected ? const Color(0xFF94001a) : const Color(0xFF5c5f60);

    return GestureDetector(
      onTap: () => setState(() => _selectedRating = rating),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppFonts.banglaHeading(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedReport() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFe2bebc)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detailed Report', style: AppFonts.banglaHeading(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF161c22))),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFeff4fd),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFe2bebc)),
            ),
            child: TextField(
              controller: _reportController,
              maxLines: 5,
              onChanged: (v) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Describe any issues encountered during the execution of this work order...',
                hintStyle: AppFonts.banglaBody(color: Color(0xFF5c5f60).withOpacity(0.7), fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
                counterText: '',
              ),
              maxLength: 500,
              style: AppFonts.banglaBody(fontSize: 14, color: Color(0xFF161c22)),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('${_reportController.text.length}/500', style: AppFonts.banglaData(fontSize: 12, color: Color(0xFF5c5f60))),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFba1a1a).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFba1a1a).withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFba1a1a)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Require Urgent Attention', style: AppFonts.banglaBody(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFba1a1a))),
                      Text('Flag this feedback for immediate review by a supervisor.', style: AppFonts.banglaBody(fontSize: 12, color: Color(0xFF5a403f))),
                    ],
                  ),
                ),
                Switch(
                  value: _isUrgent,
                  activeColor: const Color(0xFFba1a1a),
                  onChanged: (v) => setState(() => _isUrgent = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
