// lib/features/factory/presentation/screens/stock_screen.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

/// ===== Factory Dashboard Palette (kept consistent) =====
const Color _darkBlue   = Color(0xFF0D47A1); // brand/nav
const Color _accent     = Color(0xFFFFC107); // soft yellow accent
const Color _surface    = Color(0xFFF7F8FB); // panel bg
const Color _okGreen    = Color(0xFF10B981);
const Color _lowRed     = Color(0xFFE11D48);
const Color _highIndigo = Color(0xFF4338CA);
const Color _darkRed    = Color(0xFFD51616);

/// ===== Thresholds (can be overridden per item by Firestore fields) =====
const int kDefaultLowThreshold  = 100;
const int kDefaultHighThreshold = 500;

/// Cooldown to re-notify when item stays low/high (hours)
const int kAlertCooldownHours = 12;

/// Firestore Layout (recommended):
/// stocks/{docId} => {
///   name, sku, qty, unit, minThreshold, maxThreshold, lastUpdated,
///   lastAlertLowAt: Timestamp?,   // added for cooldown
///   lastAlertHighAt: Timestamp?,  // added for cooldown
/// }
/// stocks/{docId}/logs/{yyyy-MM-dd} => { date, delta, newQty, note, ts }

class StockScreen extends StatefulWidget {
  const StockScreen({Key? key}) : super(key: key);

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final _notif = FlutterLocalNotificationsPlugin();

  // Toolbar state
  String _search = '';
  _Filter _filter = _Filter.all;
  _SortBy _sort = _SortBy.nameAZ;

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _scheduleDailyReminder();
  }

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const init = InitializationSettings(android: androidInit, iOS: iosInit);
    await _notif.initialize(init);
  }

  Future<void> _scheduleDailyReminder() async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'stock_reminders',
        'Stock Reminders',
        channelDescription: 'Daily reminder to update stock',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
    try {
      await _notif.periodicallyShow(
        901, // unique id
        'Daily Stock Update',
        'Please update today’s stock in Factory → Stock.',
        RepeatInterval.daily,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Daily reminder not scheduled: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _stocksStream() {
    // server-ordered by name; further sorted client-side based on _sort
    return FirebaseFirestore.instance
        .collection('stocks')
        .orderBy('name')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _darkRed,
        foregroundColor: Colors.white,
        title: const Text('Stock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_received_rounded),
            tooltip: 'Stock In',
            onPressed: () => _openGlobalMovement(context, isIn: true),
          ),
          IconButton(
            icon: const Icon(Icons.call_made_rounded),
            tooltip: 'Stock Out',
            onPressed: () => _openGlobalMovement(context, isIn: false),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add new item',
            onPressed: () => _openCreateOrEdit(context),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stocksStream(),
        builder: (context, snap) {
          final allDocs = snap.data?.docs ?? [];

          // Computed header stats are on raw set
          final lowCount  = allDocs.where((d) => _statusFor(d.data()) == _StockStatus.low).length;
          final highCount = allDocs.where((d) => _statusFor(d.data()) == _StockStatus.high).length;
          final totalQty  = allDocs.fold<int>(0, (sum, d) => sum + (d['qty'] as int? ?? 0));

          // Client-side search/filter/sort for list
          List<QueryDocumentSnapshot<Map<String, dynamic>>> docs = List.of(allDocs);

          if (_search.trim().isNotEmpty) {
            final s = _search.trim().toLowerCase();
            docs = docs.where((d) {
              final m = d.data();
              final name = (m['name'] as String? ?? '').toLowerCase();
              final sku  = (m['sku']  as String? ?? '').toLowerCase();
              return name.contains(s) || sku.contains(s);
            }).toList();
          }

          if (_filter != _Filter.all) {
            docs = docs.where((d) => _statusFor(d.data()) == _filter.toStatus()).toList();
          }

          docs.sort((a, b) {
            final ma = a.data(), mb = b.data();
            switch (_sort) {
              case _SortBy.nameAZ:
                return (ma['name'] as String? ?? '').toLowerCase()
                    .compareTo((mb['name'] as String? ?? '').toLowerCase());
              case _SortBy.qtyLowHigh:
                return ((ma['qty'] as int?) ?? 0).compareTo(((mb['qty'] as int?) ?? 0));
              case _SortBy.qtyHighLow:
                return ((mb['qty'] as int?) ?? 0).compareTo(((ma['qty'] as int?) ?? 0));
            }
          });

          return Column(
            children: [
              const SizedBox(height: 12),
              _SummaryRow(
                totalItems: allDocs.length,
                totalQty: totalQty,
                lowCount: lowCount,
                highCount: highCount,
              ),
              if (lowCount > 0 || highCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _AlertBanner(lowCount: lowCount, highCount: highCount),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: _Toolbar(
                  search: _search,
                  onSearch: (v) => setState(() => _search = v),
                  filter: _filter,
                  onFilter: (f) => setState(() => _filter = f),
                  sort: _sort,
                  onSort: (s) => setState(() => _sort = s),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: snap.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator())
                    : _StockList(
                  docs: docs,
                  onUpdate: (doc) => _openUpdateSheet(context, doc.id, doc.data()),
                  onEdit:   (doc) => _openCreateOrEdit(context, existingId: doc.id, existing: doc.data()),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _darkRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.playlist_add_check),
        label: const Text('Daily Update'),
        onPressed: () => _quickDailyUpdate(context),
      ),
    );
  }

  Future<void> _openGlobalMovement(BuildContext context, {required bool isIn}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _GlobalMovementSheet(
          isIn: isIn,
          onSubmit: (docId, data, amount, note) async {
            final delta = isIn ? amount : -amount;
            await _applyUpdate(docId, data, delta, note);
          },
        ),
      ),
    );
  }

  Future<void> _openUpdateSheet(
      BuildContext context,
      String docId,
      Map<String, dynamic> data,
      ) async {
    final name = (data['name'] as String?) ?? 'Unnamed';
    final qty  = (data['qty'] as int?) ?? 0;
    final ctlAmount = TextEditingController(text: '1');
    final ctlNote   = TextEditingController();
    var isIn = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        int _previewNewQty() {
          final amt = int.tryParse(ctlAmount.text.trim()) ?? 0;
          final delta = isIn ? amt : -amt;
          return qty + delta;
        }

        String unit = (data['unit'] as String?) ?? 'pcs';

        return StatefulBuilder(
          builder: (ctx, setS) => Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 16,
              bottom: 16 + MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SheetHandle(),
                Text('Update • $name', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _Pill(text: 'Current: $qty', color: Colors.black87),
                    const SizedBox(width: 8),
                    _Pill(text: 'Unit: $unit', color: Colors.black54),
                  ],
                ),
                const SizedBox(height: 12),
                // In / Out toggle
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(value: true, label: Text('Stock In'), icon: Icon(Icons.call_received_rounded)),
                          ButtonSegment(value: false, label: Text('Stock Out'), icon: Icon(Icons.call_made_rounded)),
                        ],
                        selected: {isIn},
                        onSelectionChanged: (s) => setS(() { isIn = s.first; }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctlAmount,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setS(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _Pill(
                    text: 'New qty: ${_previewNewQty()} $unit',
                    color: _previewNewQty() < 0 ? _lowRed : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctlNote,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _darkRed, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                        onPressed: () async {
                          final amt = int.tryParse(ctlAmount.text.trim()) ?? 0;
                          if (amt <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a positive amount')),
                            );
                            return;
                          }
                          if (!isIn && qty - amt < 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Stock cannot go negative')),
                            );
                            return;
                          }
                          final delta = isIn ? amt : -amt;
                          await _applyUpdate(docId, data, delta, ctlNote.text.trim().isEmpty
                              ? (isIn ? 'Quick Stock In' : 'Quick Stock Out')
                              : ctlNote.text.trim());
                          if (!mounted) return;
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Stock updated')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Applies the update, logs it, and pushes notifications when thresholds are crossed or stale.
  Future<void> _applyUpdate(
      String docId,
      Map<String, dynamic> existing,
      int delta,
      String note,
      ) async {
    final prevQty   = (existing['qty'] as int?) ?? 0;
    final name      = (existing['name'] as String?) ?? 'Unnamed';
    final unit      = (existing['unit'] as String?) ?? 'pcs';
    final minT      = (existing['minThreshold'] as int?) ?? kDefaultLowThreshold;
    final maxT      = (existing['maxThreshold'] as int?) ?? kDefaultHighThreshold;

    final newQty = prevQty + delta;

    final ref = FirebaseFirestore.instance.collection('stocks').doc(docId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      tx.update(ref, {
        'qty': newQty,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      final today = DateTime.now();
      final yyyyMmDd = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';
      tx.set(ref.collection('logs').doc(yyyyMmDd), {
        'date': yyyyMmDd,
        'delta': delta,
        'newQty': newQty,
        'note': note,
        'ts': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    await _maybeSendThresholdAlert(
      docId: docId,
      name: name,
      unit: unit,
      prevQty: prevQty,
      newQty: newQty,
      minT: minT,
      maxT: maxT,
    );
  }

  Future<void> _maybeSendThresholdAlert({
    required String docId,
    required String name,
    required String unit,
    required int prevQty,
    required int newQty,
    required int minT,
    required int maxT,
  }) async {
    final doc = await FirebaseFirestore.instance.collection('stocks').doc(docId).get();
    final data = doc.data() ?? {};
    final lastLow  = (data['lastAlertLowAt']  as Timestamp?)?.toDate();
    final lastHigh = (data['lastAlertHighAt'] as Timestamp?)?.toDate();

    bool cooldownPassed(DateTime? last) {
      if (last == null) return true;
      return DateTime.now().isAfter(last.add(const Duration(hours: kAlertCooldownHours)));
    }

    // Prefer "crossing", else "still below/above but cooldown passed"
    if ((newQty < minT && prevQty >= minT) || (newQty < minT && cooldownPassed(lastLow))) {
      final title = 'Stock is LOW: $name';
      final body  = 'Qty: $newQty $unit (< $minT). Please start new production.';
      await _queueStockPushToEveryone(title, body, highPriority: true);
      await _showLocal(title, body);
      await doc.reference.set({'lastAlertLowAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } else if ((newQty > maxT && prevQty <= maxT) || (newQty > maxT && cooldownPassed(lastHigh))) {
      final title = 'Stock is HIGH: $name';
      final body  = 'Qty: $newQty $unit (> $maxT). Please start selling.';
      await _queueStockPushToEveryone(title, body, highPriority: false);
      await _showLocal(title, body);
      await doc.reference.set({'lastAlertHighAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    }
  }

  Future<void> _showLocal(String title, String body) async {
    await _notif.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'stock_reminders', 'Stock Reminders',
          channelDescription: 'General alerts & stock notifications',
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Collects UIDs of users who should receive stock notifications and queues a dispatch.
  /// Rule: if any users have `notifyStock == true`, use them; else send to ALL users.
  Future<void> _queueStockPushToEveryone(String title, String body, {required bool highPriority}) async {
    final usersCol = FirebaseFirestore.instance.collection('users');

    // Try targeted first
    final targeted = await usersCol.where('notifyStock', isEqualTo: true).get();
    List<String> uids = targeted.docs.map((d) => d.id).toList();

    if (uids.isEmpty) {
      // Fallback to everyone
      final all = await usersCol.get();
      uids = all.docs.map((d) => d.id).toList();
    }

    if (uids.isEmpty) return; // nothing to do

    await FirebaseFirestore.instance.collection('alert_dispatch').add({
      'alertId'   : null,
      'uids'      : uids,
      'title'     : title,
      'body'      : body,
      'priority'  : highPriority ? 'high' : 'normal',
      'type'      : 'stock',
      'status'    : 'pending',
      'createdAt' : FieldValue.serverTimestamp(),
    });

    // (Optional) write in-app notification docs for badges/center
    final batch = FirebaseFirestore.instance.batch();
    final notiCol = FirebaseFirestore.instance.collection('notifications');
    final now = FieldValue.serverTimestamp();
    for (final uid in uids) {
      batch.set(notiCol.doc(), {
        'toUserId'  : uid,
        'title'     : title,
        'body'      : body,
        'type'      : 'stock',
        'read'      : false,
        'createdAt' : now,
      });
    }
    await batch.commit();
  }

  Future<void> _quickDailyUpdate(BuildContext context) async {
    final snap = await FirebaseFirestore.instance.collection('stocks').orderBy('name').get();
    if (!mounted) return;

    final controllers = <String, TextEditingController>{};
    for (final d in snap.docs) {
      controllers[d.id] = TextEditingController(text: '0');
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
              left: 12, right: 12, top: 12, bottom: 12 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SheetHandle(),
              const Text('Daily Update', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: snap.docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final doc = snap.docs[i];
                    final data = doc.data();
                    final name = (data['name'] as String?) ?? 'Unnamed';
                    final qty  = (data['qty'] as int?) ?? 0;
                    final unit = (data['unit'] as String?) ?? 'pcs';
                    return Container(
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text('Current: $qty $unit', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 90,
                            child: TextField(
                              controller: controllers[doc.id],
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                labelText: 'Δ change',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _darkRed, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text('Save all'),
                  onPressed: () async {
                    for (final d in snap.docs) {
                      final text = controllers[d.id]!.text.trim();
                      final delta = int.tryParse(text) ?? 0;
                      if (delta == 0) continue;
                      await _applyUpdate(d.id, d.data(), delta, 'Daily update (bulk)');
                    }
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Daily updates saved')),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openCreateOrEdit(
      BuildContext context, {
        String? existingId,
        Map<String, dynamic>? existing,
      }) async {
    final result = await showModalBottomSheet<_StockEditResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _StockEditSheet(
          existingId: existingId,
          existing: existing,
          brandColor: _darkRed,
        ),
      ),
    );

    if (result != null) {
      final col = FirebaseFirestore.instance.collection('stocks');

      DocumentReference<Map<String, dynamic>> ref;
      if (result.docId == null) {
        ref = await col.add(result.data);
      } else {
        ref = col.doc(result.docId);
        await ref.set(result.data, SetOptions(merge: true));
      }

      await _maybeSendThresholdAlert(
        docId: ref.id,
        name: (result.data['name'] as String?) ?? 'Unnamed',
        unit: (result.data['unit'] as String?) ?? 'pcs',
        prevQty: (result.prevQty ?? result.data['qty'] as int?) ?? 0,
        newQty: (result.data['qty'] as int?) ?? 0,
        minT: (result.data['minThreshold'] as int?) ?? kDefaultLowThreshold,
        maxT: (result.data['maxThreshold'] as int?) ?? kDefaultHighThreshold,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existingId == null ? 'Stock item created' : 'Stock item updated'),
        ),
      );
    }
  }

  _StockStatus _statusFor(Map<String, dynamic> data) {
    final qty = (data['qty'] as int?) ?? 0;
    final min = (data['minThreshold'] as int?) ?? kDefaultLowThreshold;
    final max = (data['maxThreshold'] as int?) ?? kDefaultHighThreshold;
    if (qty < min) return _StockStatus.low;
    if (qty > max) return _StockStatus.high;
    return _StockStatus.ok;
  }
}

enum _StockStatus { low, high, ok }
enum _Filter { all, low, ok, high }
extension on _Filter {
  _StockStatus? toStatus() {
    switch (this) {
      case _Filter.low:  return _StockStatus.low;
      case _Filter.ok:   return _StockStatus.ok;
      case _Filter.high: return _StockStatus.high;
      case _Filter.all:  return null;
    }
  }
}
enum _SortBy { nameAZ, qtyLowHigh, qtyHighLow }

/// ================= UI Pieces =================
class _StockEditResult {
  final String? docId;
  final Map<String, dynamic> data;
  final int? prevQty;
  _StockEditResult({required this.docId, required this.data, required this.prevQty});
}

class _Toolbar extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearch;
  final _Filter filter;
  final ValueChanged<_Filter> onFilter;
  final _SortBy sort;
  final ValueChanged<_SortBy> onSort;

  const _Toolbar({
    Key? key,
    required this.search,
    required this.onSearch,
    required this.filter,
    required this.onFilter,
    required this.sort,
    required this.onSort,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          onChanged: onSearch,
          decoration: InputDecoration(
            hintText: 'Search name / SKU…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(12),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: filter == _Filter.all,
                  onSelected: (_) => onFilter(_Filter.all),
                ),
                ChoiceChip(
                  label: const Text('Low'),
                  selected: filter == _Filter.low,
                  onSelected: (_) => onFilter(_Filter.low),
                ),
                ChoiceChip(
                  label: const Text('OK'),
                  selected: filter == _Filter.ok,
                  onSelected: (_) => onFilter(_Filter.ok),
                ),
                ChoiceChip(
                  label: const Text('High'),
                  selected: filter == _Filter.high,
                  onSelected: (_) => onFilter(_Filter.high),
                ),
              ],
            ),
            const Spacer(),
            DropdownButton<_SortBy>(
              value: sort,
              underline: const SizedBox.shrink(),
              onChanged: (v) => onSort(v ?? _SortBy.nameAZ),
              items: const [
                DropdownMenuItem(value: _SortBy.nameAZ, child: Text('Name A–Z')),
                DropdownMenuItem(value: _SortBy.qtyLowHigh, child: Text('Qty ↑')),
                DropdownMenuItem(value: _SortBy.qtyHighLow, child: Text('Qty ↓')),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _StockEditSheet extends StatefulWidget {
  final String? existingId;
  final Map<String, dynamic>? existing;
  final Color brandColor;

  const _StockEditSheet({
    Key? key,
    this.existingId,
    this.existing,
    required this.brandColor,
  }) : super(key: key);

  @override
  State<_StockEditSheet> createState() => _StockEditSheetState();
}

class _StockEditSheetState extends State<_StockEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtl;
  late final TextEditingController _skuCtl;
  late final TextEditingController _qtyCtl;
  late final TextEditingController _minCtl;
  late final TextEditingController _maxCtl;

  String _unit = 'pcs';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtl = TextEditingController(text: e?['name']?.toString() ?? '');
    _skuCtl  = TextEditingController(text: e?['sku']?.toString() ?? '');
    _unit    = e?['unit']?.toString() ?? 'pcs';
    _qtyCtl  = TextEditingController(text: (e?['qty']?.toString() ?? '0'));
    _minCtl  = TextEditingController(text: (e?['minThreshold']?.toString() ?? '$kDefaultLowThreshold'));
    _maxCtl  = TextEditingController(text: (e?['maxThreshold']?.toString() ?? '$kDefaultHighThreshold'));
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _skuCtl.dispose();
    _qtyCtl.dispose();
    _minCtl.dispose();
    _maxCtl.dispose();
    super.dispose();
  }

  int get _qty => int.tryParse(_qtyCtl.text.trim()) ?? 0;
  int get _min => int.tryParse(_minCtl.text.trim()) ?? kDefaultLowThreshold;
  int get _max => int.tryParse(_maxCtl.text.trim()) ?? kDefaultHighThreshold;

  _StockStatus get _status {
    if (_qty < _min) return _StockStatus.low;
    if (_qty > _max) return _StockStatus.high;
    return _StockStatus.ok;
  }

  Color get _statusColor {
    switch (_status) {
      case _StockStatus.low:  return _lowRed;
      case _StockStatus.high: return _highIndigo;
      case _StockStatus.ok:   return _okGreen;
    }
  }

  String get _statusText {
    switch (_status) {
      case _StockStatus.low:  return 'LOW';
      case _StockStatus.high: return 'HIGH';
      case _StockStatus.ok:   return 'OK';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final map = <String, dynamic>{
      'name': _nameCtl.text.trim(),
      'sku': _skuCtl.text.trim(),
      'unit': _unit.trim(),
      'qty': _qty,
      'minThreshold': _min,
      'maxThreshold': _max,
      'lastUpdated': FieldValue.serverTimestamp(),
    };

    Navigator.of(context).pop(
      _StockEditResult(
        docId: widget.existingId,
        data: map,
        prevQty: widget.existing?['qty'] as int?,
      ),
    );
  }

  Future<void> _delete() async {
    final id = widget.existingId;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: const Text('This will remove the stock item and its data. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await FirebaseFirestore.instance.collection('stocks').doc(id).delete();
    if (!mounted) return;
    Navigator.pop(context); // close sheet
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stock item deleted')));
  }

  void _applyPreset(int min, int max) {
    _minCtl.text = '$min';
    _maxCtl.text = '$max';
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.existingId == null ? 'Add Stock Item' : 'Edit Stock Item';

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 42, height: 5,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(999)),
            ),
            // Header
            Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                // Live status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(.12),
                    border: Border.all(color: _statusColor),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(_statusText, style: TextStyle(fontWeight: FontWeight.w900, color: _statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Name
                  TextFormField(
                    controller: _nameCtl,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Name required' : null,
                  ),
                  const SizedBox(height: 10),

                  // SKU + Unit row
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _skuCtl,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'SKU / Code',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _unit,
                          items: const [
                            DropdownMenuItem(value: 'pcs', child: Text('pcs')),
                            DropdownMenuItem(value: 'kg',  child: Text('kg')),
                            DropdownMenuItem(value: 'm',   child: Text('m')),
                            DropdownMenuItem(value: 'box', child: Text('box')),
                          ],
                          onChanged: (v) => setState(() => _unit = v ?? 'pcs'),
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Qty + stepper
                  _QtyStepper(
                    label: 'Quantity',
                    controller: _qtyCtl,
                    color: widget.brandColor,
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 10),

                  // Thresholds side-by-side
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _minCtl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Low threshold',
                            border: OutlineInputBorder(),
                          ),
                          validator: (_) {
                            final mn = int.tryParse(_minCtl.text.trim());
                            final mx = int.tryParse(_maxCtl.text.trim());
                            if (mn == null) return 'Enter a number';
                            if (mx != null && mn >= mx) return 'Must be < High';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _maxCtl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'High threshold',
                            border: OutlineInputBorder(),
                          ),
                          validator: (_) {
                            final mn = int.tryParse(_minCtl.text.trim());
                            final mx = int.tryParse(_maxCtl.text.trim());
                            if (mx == null) return 'Enter a number';
                            if (mn != null && mx <= mn) return 'Must be > Low';
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),

                  // Quick presets
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Preset 100–500'),
                          onPressed: () => _applyPreset(100, 500),
                        ),
                        ActionChip(
                          label: const Text('Preset 50–300'),
                          onPressed: () => _applyPreset(50, 300),
                        ),
                        ActionChip(
                          label: const Text('Preset 0–999'),
                          onPressed: () => _applyPreset(0, 999),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Buttons
                  Row(
                    children: [
                      if (widget.existingId != null)
                        TextButton.icon(
                          onPressed: _saving ? null : _delete,
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: widget.brandColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: _saving
                            ? const SizedBox(
                          height: 18, width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                            : const Icon(Icons.save_rounded),
                        label: Text(_saving ? 'Saving…' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final Color color;
  final VoidCallback? onChanged;

  const _QtyStepper({
    Key? key,
    required this.label,
    required this.controller,
    required this.color,
    this.onChanged,
  }) : super(key: key);

  int get _value => int.tryParse(controller.text.trim()) ?? 0;

  void _set(TextEditingController c, int v) {
    c.text = v.toString();
    onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => onChanged?.call(),
            ),
          ),
          const SizedBox(width: 10),
          _RoundIconBtn(
            icon: Icons.remove,
            onTap: () => _set(controller, (_value - 1).clamp(-999999, 999999)),
          ),
          const SizedBox(width: 8),
          _RoundIconBtn(
            icon: Icons.add,
            onTap: () => _set(controller, (_value + 1).clamp(-999999, 999999)),
            color: color,
            fg: Colors.white,
          ),
        ],
      ),
    );
  }
}

class _RoundIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? fg;

  const _RoundIconBtn({Key? key, required this.icon, required this.onTap, this.color, this.fg}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color ?? Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12),
          ),
          child: Icon(icon, color: fg ?? _darkBlue),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final int totalItems;
  final int totalQty;
  final int lowCount;
  final int highCount;

  const _SummaryRow({
    Key? key,
    required this.totalItems,
    required this.totalQty,
    required this.lowCount,
    required this.highCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const spacing = 10.0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: LayoutBuilder(
        builder: (ctx, c) {
          final w = c.maxWidth;
          final cardW = (w - spacing) / 2; // 2 columns on phones
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              _SummaryCard(
                width: cardW,
                title: 'Total Items',
                value: totalItems,
                color: _darkBlue,
              ),
              _SummaryCard(
                width: cardW,
                title: 'Total Qty',
                value: totalQty,
                color: _accent,
                textDark: true,
              ),
              _SummaryCard(
                width: cardW,
                title: 'Low (<$kDefaultLowThreshold)',
                value: lowCount,
                color: _lowRed,
              ),
              _SummaryCard(
                width: cardW,
                title: 'High (>$kDefaultHighThreshold)',
                value: highCount,
                color: _highIndigo,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatefulWidget {
  final double width;
  final String title;
  final int value;
  final Color color;
  final bool textDark;

  const _SummaryCard({
    Key? key,
    required this.width,
    required this.title,
    required this.value,
    required this.color,
    this.textDark = false,
  }) : super(key: key);

  @override
  State<_SummaryCard> createState() => _SummaryCardState();
}

class _SummaryCardState extends State<_SummaryCard> with SingleTickerProviderStateMixin {
  late int _displayValue;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _displayValue = widget.value;
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _SummaryCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller
        ..reset()
        ..forward();
      _displayValue = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.textDark ? Colors.black87 : Colors.white;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.scale(
          scale: 0.98 + (_controller.value * 0.02),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: widget.width,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: widget.color.withOpacity(0.25), blurRadius: 10, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title, style: TextStyle(color: fg.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  child: Text(
                    '$_displayValue',
                    key: ValueKey<int>(_displayValue),
                    style: TextStyle(color: fg, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final int lowCount;
  final int highCount;

  const _AlertBanner({Key? key, required this.lowCount, required this.highCount}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final msgs = <String>[];
    if (lowCount > 0) msgs.add('$lowCount item(s) are LOW');
    if (highCount > 0) msgs.add('$highCount item(s) are HIGH');
    return Material(
      elevation: 0,
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: (lowCount > 0 ? _lowRed : _highIndigo), width: 5)),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              lowCount > 0 ? Icons.warning_amber_rounded : Icons.info_rounded,
              color: lowCount > 0 ? _lowRed : _highIndigo,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msgs.join(' • '),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockList extends StatelessWidget {
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>>) onUpdate;
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>>) onEdit;

  const _StockList({
    Key? key,
    required this.docs,
    required this.onUpdate,
    required this.onEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: ListView.separated(
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final d = docs[i];
          final data = d.data();
          final name = (data['name'] as String?) ?? 'Unnamed';
          final sku  = (data['sku'] as String?) ?? '';
          final qty  = (data['qty'] as int?) ?? 0;
          final unit = (data['unit'] as String?) ?? 'pcs';
          final status = _statusFor(data);

          Color borderColor;
          Color chipColor;
          String chipText;
          switch (status) {
            case _StockStatus.low:
              borderColor = _lowRed;
              chipColor = _lowRed.withOpacity(0.12);
              chipText  = 'LOW';
              break;
            case _StockStatus.high:
              borderColor = _highIndigo;
              chipColor = _highIndigo.withOpacity(0.12);
              chipText  = 'HIGH';
              break;
            default:
              borderColor = _okGreen;
              chipColor = _okGreen.withOpacity(0.12);
              chipText  = 'OK';
          }

          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: ListTile(
              onLongPress: () => onUpdate(d),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (sku.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: _Pill(text: sku, color: Colors.black54),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    _Pill(text: '$qty $unit', color: Colors.black87),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: chipColor,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: borderColor),
                      ),
                      child: Text(chipText, style: TextStyle(color: borderColor, fontWeight: FontWeight.w700)),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Update',
                      icon: const Icon(Icons.trending_up_rounded, color: _darkRed),
                      onPressed: () => onUpdate(d),
                    ),
                    IconButton(
                      tooltip: 'Edit item',
                      icon: const Icon(Icons.edit, color: Colors.black54),
                      onPressed: () => onEdit(d),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  _StockStatus _statusFor(Map<String, dynamic> data) {
    final qty = (data['qty'] as int?) ?? 0;
    final min = (data['minThreshold'] as int?) ?? kDefaultLowThreshold;
    final max = (data['maxThreshold'] as int?) ?? kDefaultHighThreshold;
    if (qty < min) return _StockStatus.low;
    if (qty > max) return _StockStatus.high;
    return _StockStatus.ok;
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;

  const _Pill({Key? key, required this.text, required this.color}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 5,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

/* ===== Global Movement Bottom Sheet (pick any item, then In/Out amount) ===== */
class _GlobalMovementSheet extends StatefulWidget {
  final bool isIn;
  final Future<void> Function(String docId, Map<String, dynamic> data, int amount, String note) onSubmit;

  const _GlobalMovementSheet({
    Key? key,
    required this.isIn,
    required this.onSubmit,
  }) : super(key: key);

  @override
  State<_GlobalMovementSheet> createState() => _GlobalMovementSheetState();
}

class _GlobalMovementSheetState extends State<_GlobalMovementSheet> {
  String? _selectedId;
  Map<String, dynamic>? _selectedData;
  final _amountCtl = TextEditingController(text: '1');
  final _noteCtl   = TextEditingController();

  @override
  void dispose() {
    _amountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isIn ? 'Stock In' : 'Stock Out';
    final accent = widget.isIn ? _okGreen : _lowRed;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHandle(),
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              Icon(widget.isIn ? Icons.call_received_rounded : Icons.call_made_rounded, color: accent),
            ],
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('stocks').orderBy('name').snapshots(),
            builder: (ctx, snap) {
              final docs = snap.data?.docs ?? [];
              return DropdownButtonFormField<String>(
                value: _selectedId,
                items: docs.map((d) {
                  final m = d.data();
                  final name = (m['name'] as String?) ?? 'Unnamed';
                  final sku  = (m['sku'] as String?) ?? '';
                  return DropdownMenuItem<String>(
                    value: d.id,
                    child: Row(
                      children: [
                        Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
                        if (sku.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text('($sku)', style: const TextStyle(color: Colors.black54)),
                          ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (v) async {
                  setState(() => _selectedId = v);
                  if (v != null) {
                    final doc = await FirebaseFirestore.instance.collection('stocks').doc(v).get();
                    setState(() => _selectedData = doc.data());
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Select item',
                  border: OutlineInputBorder(),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _amountCtl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              if (_selectedData != null)
                _Pill(text: (_selectedData!['unit'] as String? ?? 'pcs'), color: Colors.black87),
            ],
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: _noteCtl,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.save_rounded),
              label: Text(widget.isIn ? 'Save Stock In' : 'Save Stock Out'),
              onPressed: () async {
                final amt = int.tryParse(_amountCtl.text.trim()) ?? 0;
                if (_selectedId == null || _selectedData == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select an item')),
                  );
                  return;
                }
                if (amt <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter a positive amount')),
                  );
                  return;
                }
                final note = _noteCtl.text.trim().isEmpty
                    ? (widget.isIn ? 'Quick Stock In' : 'Quick Stock Out')
                    : _noteCtl.text.trim();
                await widget.onSubmit(_selectedId!, _selectedData!, amt, note);
                if (!mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${widget.isIn ? 'Stock In' : 'Stock Out'} saved')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
