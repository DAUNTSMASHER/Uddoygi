// lib/features/rnd/presentation/screens/rnd_notices_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/features/rnd/rnd_theme.dart';
import 'package:intl/intl.dart';


class RndNoticesScreen extends StatefulWidget {
  const RndNoticesScreen({super.key});

  @override
  State<RndNoticesScreen> createState() => _RndNoticesScreenState();
}

class _RndNoticesScreenState extends State<RndNoticesScreen> {
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
    return Scaffold(
      backgroundColor: rndSurface,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [rndBrandDk, rndMid],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        title: const Text('Notices',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _cid.isEmpty ? const Stream.empty() : DB.colSync(_cid, C.notices)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: rndBrand));
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('No notices.',
                style: TextStyle(color: Colors.black38)));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final m  = docs[i].data() as Map<String, dynamic>;
              final ts = m['createdAt'];
              final dt = ts is Timestamp ? ts.toDate() : null;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: rndCardTint),
                  boxShadow: const [BoxShadow(color: Color(0x06000000),
                      blurRadius: 6, offset: Offset(0, 2))],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [rndBrand, rndMid],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.announcement_rounded,
                          size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(m['title'] ?? '—',
                        style: const TextStyle(fontSize: 14,
                            fontWeight: FontWeight.w700))),
                    if (dt != null)
                      Text(DateFormat('d MMM').format(dt),
                          style: const TextStyle(fontSize: 11,
                              color: Colors.black38)),
                  ]),
                  if ((m['body'] ?? m['content'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(m['body'] ?? m['content'] ?? '',
                        style: const TextStyle(fontSize: 13,
                            color: Colors.black54)),
                  ],
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
