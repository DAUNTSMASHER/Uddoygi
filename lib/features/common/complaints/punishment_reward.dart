import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PunishmentRewardScreen extends StatefulWidget {
  final String userEmail;

  const PunishmentRewardScreen({
    super.key,
    required this.userEmail,
  });

  @override
  State<PunishmentRewardScreen> createState() => _PunishmentRewardScreenState();
}

class _PunishmentRewardScreenState extends State<PunishmentRewardScreen> {
  @override
  Widget build(BuildContext context) {
    final query = FirebaseFirestore.instance
        .collection('punishments')
        .where(Filter.or(
      Filter('forEmail', isEqualTo: widget.userEmail),
      Filter('givenBy', isEqualTo: widget.userEmail),
    ))
        .orderBy('timestamp', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Punishment & Reward"),
        backgroundColor: Colors.indigo,
      ),
      backgroundColor: Colors.indigo[50],
      body: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text("No entries.", style: TextStyle(color: Colors.indigo, fontSize: 16)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final type = d['type'] ?? 'punishment';
              final desc = d['description'] ?? '';
              final forEmail = d['forEmail'] ?? '';
              final givenBy = d['givenBy'] ?? '';
              final ts = d['timestamp'];
              final time = ts is Timestamp
                  ? DateFormat('MMM d, y h:mm a').format(ts.toDate())
                  : '';
              final appealed = d['appealed'] == true;
              final appealText = d['appealText'] ?? '';

              final isReward = type == 'reward';
              final statusColor = isReward ? Colors.green : Colors.redAccent;

              // Dynamic message based on user role
              final message = widget.userEmail == forEmail
                  ? isReward
                  ? "🎉 Congratulations! You received a reward for: $desc"
                  : "😔 Sorry! You have been punished for: $desc"
                  : "📢 You issued a ${isReward ? "reward" : "punishment"} to $forEmail for: $desc";

              return Card(
                color: statusColor.withOpacity(0.1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: Icon(
                    isReward ? Icons.thumb_up : Icons.thumb_down,
                    color: statusColor,
                  ),
                  title: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("From: $givenBy", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      Text("To: $forEmail", style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      if (time.isNotEmpty)
                        Text("On: $time", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      if (appealed)
                        Text("Appealed: $appealText", style: const TextStyle(fontSize: 12, color: Colors.orange)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
