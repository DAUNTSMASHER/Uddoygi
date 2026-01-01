import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin_report_detail.dart';

class AdminModuleHub extends StatelessWidget {
  final String title;
  final String? orgId;
  final DateTimeRange range;
  final List<String> labels;

  const AdminModuleHub({
    super.key,
    required this.title,
    required this.orgId,
    required this.range,
    required this.labels,
  });

  static const _p1 = Color(0xFF2E1065);
  static const _p2 = Color(0xFF5B21B6);
  static const _p3 = Color(0xFF7C3AED);
  static const _bg = Color(0xFFF7F7FB);
  static const _border = Color(0xFFE7E9F3);
  static const _text = Color(0xFF0F172A);
  static const _text2 = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        elevation: 0,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        foregroundColor: Colors.white,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_p1, _p2, _p3],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select a report',
              style: TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Range: ${range.start.toString().split(" ").first} → ${range.end.subtract(const Duration(days: 1)).toString().split(" ").first}',
              style: const TextStyle(color: _text2, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: GridView.builder(
                itemCount: labels.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.35,
                ),
                itemBuilder: (_, i) {
                  final label = labels[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminReportDetailPage(
                            orgId: orgId,
                            range: range,
                            headTitle: title,
                            label: label,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.white,
                        border: Border.all(color: _border),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 36,
                            width: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [_p2, _p3],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(Icons.insert_chart_rounded, color: Colors.white, size: 18),
                          ),
                          const Spacer(),
                          Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900, color: _text),
                          ),
                          const SizedBox(height: 2),
                          const Text('Tap to open', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _text2)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
