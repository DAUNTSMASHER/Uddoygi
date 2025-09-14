import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// ===== Green palette (match HR) =====
const Color _brandGreen = Color(0xFF065F46); // deep green
const Color _greenMid   = Color(0xFF10B981); // accent
const Color _surface    = Color(0xFFF1F8F4); // light surface
const Color _border     = Color(0x1A065F46); // 10% green

class AlertPage extends StatefulWidget {
  const AlertPage({Key? key}) : super(key: key);

  @override
  State<AlertPage> createState() => _AlertPageState();
}

enum _AlertMode { individuals, department }

class _AlertPageState extends State<AlertPage> {
  _AlertMode _mode = _AlertMode.individuals;

  final _searchCtl = TextEditingController();
  final _msgCtl    = TextEditingController();

  final _selectedUserIds = <String>{};
  String? _selectedDepartment;
  bool _highPriority = true;
  bool _sending = false;

  // ---------- Streams ----------

  /// Users list with lightweight model + client-side filter.
  Stream<List<_UserLite>> _usersStream(String query) {
    return FirebaseFirestore.instance.collection('users').snapshots().map((s) {
      final q = query.trim().toLowerCase();
      final out = <_UserLite>[];
      for (final d in s.docs) {
        final m = d.data();
        final u = _UserLite(
          id: d.id,
          name: (m['fullName'] ?? m['name'] ?? m['email'] ?? 'Unknown').toString(),
          email: (m['email'] ?? '').toString(),
          department: (m['department'] ?? '').toString(),
        );
        if (q.isEmpty ||
            u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.department.toLowerCase().contains(q)) {
          out.add(u);
        }
      }
      out.sort((a, b) => a.name.compareTo(b.name));
      return out;
    });
  }

  /// Unique departments from users.department
  Stream<List<String>> _departmentsStream() {
    return FirebaseFirestore.instance.collection('users').snapshots().map((s) {
      final set = <String>{};
      for (final d in s.docs) {
        final dep = (d.data()['department'] ?? '').toString().trim();
        if (dep.isNotEmpty) set.add(dep);
      }
      final list = set.toList()..sort();
      return list;
    });
  }

  // ---------- Actions ----------

  Future<void> _sendAlert() async {
    if (_sending) return;

    final me = FirebaseAuth.instance.currentUser;
    if (me == null) {
      _toast('You must be logged in.');
      return;
    }

    final message = _msgCtl.text.trim();
    if (message.isEmpty) {
      _toast('Message is required.');
      return;
    }

    setState(() => _sending = true);

    try {
      final now = DateTime.now();

      String? department;
      List<_UserLite> recipients = <_UserLite>[];

      // -------- Resolve recipients --------
      if (_mode == _AlertMode.individuals) {
        if (_selectedUserIds.isEmpty) {
          _toast('Select at least one person.');
          setState(() => _sending = false);
          return;
        }

        final snaps = await Future.wait(
          _selectedUserIds.map((id) =>
              FirebaseFirestore.instance.collection('users').doc(id).get()),
        );

        recipients = snaps.where((d) => d.exists).map((d) {
          final m = d.data() as Map<String, dynamic>;
          return _UserLite(
            id: d.id,
            name: (m['fullName'] ?? m['name'] ?? m['email'] ?? 'User').toString(),
            email: (m['email'] ?? '').toString(),
            department: (m['department'] ?? '').toString(),
          );
        }).toList();

        if (recipients.isEmpty) {
          _toast('Selected users not found.');
          setState(() => _sending = false);
          return;
        }
      } else {
        department = _selectedDepartment?.trim();
        if (department == null || department.isEmpty) {
          _toast('Pick a department.');
          setState(() => _sending = false);
          return;
        }

        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('department', isEqualTo: department)
            .get();

        recipients = q.docs.map((d) {
          final m = d.data();
          return _UserLite(
            id: d.id,
            name: (m['fullName'] ?? m['name'] ?? m['email'] ?? 'User').toString(),
            email: (m['email'] ?? '').toString(),
            department: (m['department'] ?? '').toString(),
          );
        }).toList();

        if (recipients.isEmpty) {
          _toast('No users found in $department.');
          setState(() => _sending = false);
          return;
        }
      }

      // -------- Create master alert doc --------
      final alertRef = await FirebaseFirestore.instance.collection('alerts').add({
        'message'        : message,
        'priority'       : _highPriority ? 'high' : 'normal',
        'mode'           : _mode.name,
        'department'     : department,
        'recipientIds'   : recipients.map((e) => e.id).toList(),
        'recipientEmails': recipients.map((e) => e.email).toList(),
        'requiresAck'    : true,
        'acknowledgedBy' : <String>[],
        'active'         : true,
        'createdById'    : me.uid,
        'createdByEmail' : me.email,
        'createdAt'      : Timestamp.fromDate(now),
        'updatedAt'      : Timestamp.fromDate(now),
      });

      // -------- Fan-out in-app notifications --------
      if (recipients.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        final col = FirebaseFirestore.instance.collection('notifications');
        for (final r in recipients) {
          batch.set(col.doc(), {
            'to'        : r.email,
            'toUserId'  : r.id,
            'title'     : _highPriority ? 'URGENT Alert' : 'Alert',
            'body'      : message,
            'type'      : 'alert',
            'alertId'   : alertRef.id,
            'read'      : false,
            'createdAt' : Timestamp.fromDate(now),
          });
        }
        await batch.commit();
      }

      // -------- Queue push for worker --------
      final uidList = recipients.map((r) => r.id).toList();

      // Gather tokens (dedupe): prefer top-level array; fallback to /fcmTokens subcollection
      final tokenSet = <String>{};
      try {
        for (final uid in uidList) {
          final udoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final udata = udoc.data() as Map<String, dynamic>?;

          // 1) top-level array
          final arr = (udata?['fcmTokens'] as List?)?.whereType<String>() ?? const <String>[];
          tokenSet.addAll(arr.map((t) => t.trim()).where((t) => t.isNotEmpty));

          // 2) subcollection fallback
          if (arr.isEmpty) {
            final sub = await FirebaseFirestore.instance
                .collection('users').doc(uid)
                .collection('fcmTokens')
                .get();
            for (final d in sub.docs) {
              final m = d.data();
              final t = (m['token'] as String?)?.trim();
              if (t != null && t.isNotEmpty) tokenSet.add(t);
            }
          }
        }
      } catch (_) {
        // non-fatal; worker can still resolve tokens by uid
      }

      final dispatchDoc = {
        'alertId'    : alertRef.id,
        'uids'       : uidList,
        'tokens'     : tokenSet.toList(),
        'title'      : _highPriority ? 'URGENT Alert' : 'Alert',
        'body'       : message,
        'priority'   : _highPriority ? 'high' : 'normal',
        'status'     : 'pending',
        'createdAt'  : FieldValue.serverTimestamp(),
        'createdAtMs': DateTime.now().millisecondsSinceEpoch,
        'byUid'      : me.uid,
        'byEmail'    : me.email,
      };

      final queued = await FirebaseFirestore.instance
          .collection('alert_dispatch')
          .add(dispatchDoc);

      debugPrint('📣 queued alert_dispatch ${queued.id} → $dispatchDoc');

      // -------- Reset UI & confirm --------
      if (!mounted) return;
      _msgCtl.clear();
      _selectedUserIds.clear();
      _selectedDepartment = null;
      setState(() => _sending = false);

      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Alert queued'),
          content: Text(
            _mode == _AlertMode.individuals
                ? 'Queued for ${uidList.length} recipient(s).'
                : 'Broadcast to $department (${uidList.length} user(s)).',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    } catch (e) {
      setState(() => _sending = false);
      _toast('Failed: $e');
    }
  }


  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, maxLines: 1, overflow: TextOverflow.ellipsis),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _msgCtl.dispose();
    super.dispose();
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _brandGreen,
        foregroundColor: Colors.white,
        title: const Text(
          'Send Alert',
          style: TextStyle(fontWeight: FontWeight.w800),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // Mode + priority (responsive; avoids overflow on small widths)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 380;
                if (isNarrow) {
                  // Stack vertically
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _ModeChip(
                            text: 'Individuals',
                            selected: _mode == _AlertMode.individuals,
                            onTap: () => setState(() => _mode = _AlertMode.individuals),
                          ),
                          const SizedBox(width: 8),
                          _ModeChip(
                            text: 'Department',
                            selected: _mode == _AlertMode.department,
                            onTap: () => setState(() => _mode = _AlertMode.department),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Flexible(
                            child: Text(
                              'High priority',
                              style: TextStyle(fontWeight: FontWeight.w700, color: _brandGreen),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _highPriority,
                            activeColor: _greenMid,
                            onChanged: (v) => setState(() => _highPriority = v),
                          ),
                        ],
                      ),
                    ],
                  );
                }

                // Wide: single row
                return Row(
                  children: [
                    _ModeChip(
                      text: 'Individuals',
                      selected: _mode == _AlertMode.individuals,
                      onTap: () => setState(() => _mode = _AlertMode.individuals),
                    ),
                    const SizedBox(width: 8),
                    _ModeChip(
                      text: 'Department',
                      selected: _mode == _AlertMode.department,
                      onTap: () => setState(() => _mode = _AlertMode.department),
                    ),
                    const Spacer(),
                    const Flexible(
                      child: Text(
                        'High priority',
                        style: TextStyle(fontWeight: FontWeight.w700, color: _brandGreen),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _highPriority,
                      activeColor: _greenMid,
                      onChanged: (v) => setState(() => _highPriority = v),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Quick-add me (if logged in)
          if (me != null && _mode == _AlertMode.individuals)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    if (_selectedUserIds.contains(me.uid)) {
                      _selectedUserIds.remove(me.uid);
                    } else {
                      _selectedUserIds.add(me.uid);
                    }
                  });
                },
                icon: Icon(
                  _selectedUserIds.contains(me.uid) ? Icons.check_circle : Icons.add_circle_outline,
                  color: _brandGreen,
                ),
                label: const Text('Select myself', overflow: TextOverflow.ellipsis),
              ),
            ),

          // Individuals selector
          if (_mode == _AlertMode.individuals) ...[
            TextField(
              controller: _searchCtl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search name, email, department…',
                prefixIcon: const Icon(Icons.search, color: _brandGreen),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _border),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: StreamBuilder<List<_UserLite>>(
                stream: _usersStream(_searchCtl.text),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  final users = snap.data!;
                  if (users.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('No users found', maxLines: 1, overflow: TextOverflow.ellipsis),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const Divider(height: 0),
                    itemBuilder: (_, i) {
                      final u = users[i];
                      final selected = _selectedUserIds.contains(u.id);
                      return CheckboxListTile(
                        value: selected,
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedUserIds.add(u.id);
                            } else {
                              _selectedUserIds.remove(u.id);
                            }
                          });
                        },
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        secondary: CircleAvatar(
                          radius: 14,
                          backgroundColor: _brandGreen.withOpacity(.10),
                          child: const Icon(Icons.person, color: _brandGreen, size: 16),
                        ),
                        title: Text(
                          u.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: _brandGreen),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${u.email} • ${u.department}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            if (_selectedUserIds.isNotEmpty)
              Text(
                '${_selectedUserIds.length} recipient(s) selected',
                style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ] else ...[
            // Department dropdown
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: StreamBuilder<List<String>>(
                stream: _departmentsStream(),
                builder: (_, snap) {
                  final deps = snap.data ?? const <String>[];
                  return DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedDepartment,
                      hint: const Text('Select a department', maxLines: 1, overflow: TextOverflow.ellipsis),
                      items: deps
                          .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text(
                          d,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _brandGreen, fontWeight: FontWeight.w700),
                        ),
                      ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedDepartment = v),
                    ),
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Message (single-line label; content can be multiline)
          TextField(
            controller: _msgCtl,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Short message *',
              labelStyle: const TextStyle(overflow: TextOverflow.ellipsis),
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _sending ? null : _sendAlert,
              icon: _sending
                  ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.campaign),
              label: Text(
                _sending ? 'Sending…' : 'Send Alert',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _brandGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: selected ? Colors.white : _brandGreen,
          overflow: TextOverflow.ellipsis, // strictly single-line
        ),
        maxLines: 1,
      ),
      selected: selected,
      selectedColor: _brandGreen,
      backgroundColor: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: selected ? _brandGreen : _border)),
      onSelected: (_) => onTap(),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _UserLite {
  final String id;
  final String name;
  final String email;
  final String department;
  const _UserLite({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
  });
}
