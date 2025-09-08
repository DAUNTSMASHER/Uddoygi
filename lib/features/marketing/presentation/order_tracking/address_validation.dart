// lib/features/factory/presentation/screens/address_validation_page.dart

import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

const Color _darkBlue = Color(0xFF0D47A1);
const Color _softYellow = Color(0xFFFFC107);
const Color _panel = Color(0xFFF7F8FB);

const String _addressStage = 'Address validation';
const String _addressValidatedStage = 'Address validated';
const String _finalTrackingStage = 'Final tracking code';

/// ✅ Use HASH route for Flutter Web so deep links resolve without urlStrategy.
/// Example: https://uddyogi.web.app/#/address-confirm?token=abc123
const String _publicConfirmBaseUrl = 'https://uddyogi.web.app/#/address-confirm';
// If you’ve enabled path URL strategy, you can switch to:
// const String _publicConfirmBaseUrl = 'https://uddyogi.web.app/address-confirm';

class AddressValidationPage extends StatelessWidget {
  const AddressValidationPage({Key? key}) : super(key: key);

  Stream<QuerySnapshot<Map<String, dynamic>>> get _ordersToValidateStream =>
      FirebaseFirestore.instance
          .collection('work_orders')
          .where('currentStage', isEqualTo: _addressStage)
          .orderBy('lastUpdated', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _panel,
      appBar: AppBar(
        title: const Text('Address Validation'),
        centerTitle: true,
        backgroundColor: _darkBlue,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _ordersToValidateStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final doc = docs[i];
              final data = doc.data();
              final woNo = (data['workOrderNo'] as String?) ?? '—';
              final av = (data['addressValidation'] as Map<String, dynamic>?) ?? {};
              final token = av['token'] as String?;
              final status = (av['status'] as String?) ?? 'pending';

              return _OrderValidationCard(
                orderDocId: doc.id,
                workOrderNo: woNo,
                existingToken: token,
                existingStatus: status,
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 6))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.inbox_outlined, color: _darkBlue),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'No orders currently awaiting address validation.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// —————————————————————————————————————————————————————————————
/// ORDER CARD — one-click: prompt → generate → email (SMTP) → live QR
/// —————————————————————————————————————————————————————————————
class _OrderValidationCard extends StatefulWidget {
  const _OrderValidationCard({
    Key? key,
    required this.orderDocId,
    required this.workOrderNo,
    this.existingToken,
    this.existingStatus,
  }) : super(key: key);

  final String orderDocId;
  final String workOrderNo;
  final String? existingToken;
  final String? existingStatus;

  @override
  State<_OrderValidationCard> createState() => _OrderValidationCardState();
}

class _OrderValidationCardState extends State<_OrderValidationCard> {
  bool _busy = false;

  // ❌ DO NOT mark as @override — this is a helper, not overriding anything.
  Widget _roundedField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboard,
    int lines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black12),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: lines,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey.shade700),
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.existingStatus ?? 'pending';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    'WO# ${widget.workOrderNo}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _darkBlue),
                  ),
                ),
                _StatusPill(status: status),
              ],
            ),
            const SizedBox(height: 8),

            // ONE CLICK BUTTON — opens bottom sheet (email + message), then does the flow
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _softYellow,
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.qr_code_2),
                label: Text(_busy ? 'Working...' : 'Send Validation (QR + Link)'),
                onPressed: _busy ? null : () => _openPromptAndRun(context),
              ),
            ),

            // Live watcher after token exists
            if (widget.existingToken != null) ...[
              const SizedBox(height: 12),
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('address_validations')
                    .doc(widget.existingToken)
                    .snapshots(),
                builder: (ctx, s) {
                  final confirmed = (s.data?.data()?['status'] == 'confirmed');
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _InfoRow(
                        label: 'Confirmation',
                        value: confirmed ? 'CONFIRMED' : 'PENDING',
                        color: confirmed ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: confirmed ? Colors.green : Colors.grey.shade300,
                                foregroundColor: confirmed ? Colors.white : Colors.black54,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _busy || !confirmed ? null : _markAddressValidated,
                              child: const Text('Mark Address Validated'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _darkBlue,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _busy || !confirmed ? null : _moveToFedex,
                              child: const Text('Next: FedEx Tracking Number'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Bottom sheet prompt → runs the entire flow when you press "Send"
  Future<void> _openPromptAndRun(BuildContext context) async {
    final emailCtl = TextEditingController();
    final msgCtl = TextEditingController(
      text:
      'Please confirm your shipping address for Work Order ${widget.workOrderNo}.\n'
          'Tap the link and press “It’s OK”, or scan the QR code.\n\nThank you.',
    );
    final formKey = GlobalKey<FormState>();

    final result = await showModalBottomSheet<_PromptResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Send Address Validation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _darkBlue),
                ),
                const SizedBox(height: 12),
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      _roundedField(
                        controller: emailCtl,
                        hint: 'client@example.com',
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        validator: (v) {
                          final s = v?.trim() ?? '';
                          final re = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                          if (s.isEmpty) return 'Email is required';
                          if (!re.hasMatch(s)) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      _roundedField(
                        controller: msgCtl,
                        hint: 'Message to the client…',
                        icon: Icons.chat_bubble_outline,
                        lines: 3,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Message is required' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _darkBlue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        Navigator.pop(ctx, _PromptResult(emailCtl.text.trim(), msgCtl.text.trim()));
                      }
                    },
                    label: const Text('Send'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null) return;
    await _generateEmailAndShow(email: result.email, message: result.message);
  }

  /// Generate token + QR, write Firestore, email via SMTP, then show live QR page.
  Future<void> _generateEmailAndShow({required String email, required String message}) async {
    if (kIsWeb) {
      // Mailer package does not work on web. Let users still proceed (QR + link + share fallback).
      _snack('Running in web: SMTP email will use Share dialog fallback.');
    }

    setState(() => _busy = true);
    try {
      final now = Timestamp.now();
      final token = _makeToken();
      final url = '$_publicConfirmBaseUrl?token=$token';

      // 1) Firestore address_validations/{token}
      await FirebaseFirestore.instance.collection('address_validations').doc(token).set({
        'token': token,
        'workOrderId': widget.orderDocId,
        'workOrderNo': widget.workOrderNo,
        'status': 'pending',
        'createdAt': now,
        'confirmedAt': null,
        'recipient': email,
      });

      // 2) Attach to work_order
      await FirebaseFirestore.instance.collection('work_orders').doc(widget.orderDocId).update({
        'addressValidation': {
          'token': token,
          'url': url,
          'status': 'pending',
          'createdAt': now,
          'recipient': email,
        },
        'lastUpdated': now,
      });

      // 3) QR PNG file for attachment
      final qrPath = await _qrPngFile(url, 'qr_$token.png');

      // 4) Email directly via SMTP (mobile/desktop); fallback to share sheet on web or failure
      await _sendEmailSmtp(
        to: email,
        subject: 'Confirm your address (WO ${widget.workOrderNo})',
        body: '$message\n\n$url',
        attachmentPath: qrPath,
      );

      if (!mounted) return;

      // 5) Show a live QR watcher page so you can track confirmation instantly
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _QrLivePage(workOrderNo: widget.workOrderNo, token: token, url: url, qrPath: qrPath),
        ),
      );
    } catch (e) {
      if (mounted) _snack('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// SMTP email — reads config from Firestore: smtp_config/default
  Future<void> _sendEmailSmtp({
    required String to,
    required String subject,
    required String body,
    required String attachmentPath,
  }) async {
    try {
      final cfgSnap = await FirebaseFirestore.instance.collection('smtp_config').doc('default').get();

      if (!cfgSnap.exists) {
        // Fallback when SMTP isn’t configured: use share sheet with the QR and body text.
        await Share.shareXFiles([XFile(attachmentPath)], text: body, subject: subject);
        return;
      }

      final cfg = cfgSnap.data()!;
      final host = cfg['host'] as String;
      final port = (cfg['port'] as num).toInt();
      final user = cfg['username'] as String;
      final pass = cfg['password'] as String;
      final useSsl = (cfg['useSsl'] as bool?) ?? true;
      final fromEmail = (cfg['fromEmail'] as String?) ?? user;
      final fromName = (cfg['fromName'] as String?) ?? 'Uddyogi';

      final server = SmtpServer(host, port: port, ssl: useSsl, username: user, password: pass);

      final message = Message()
        ..from = Address(fromEmail, fromName)
        ..recipients = [to]
        ..subject = subject
        ..text = body
        ..attachments = [FileAttachment(File(attachmentPath))];

      await send(message, server);
    } on MailerException catch (e) {
      debugPrint('SMTP send failed: $e');
      await Share.shareXFiles([XFile(attachmentPath)], text: body, subject: subject);
    } catch (e) {
      debugPrint('Email fallback error: $e');
      await Share.shareXFiles([XFile(attachmentPath)], text: body, subject: subject);
    }
  }

  Future<void> _markAddressValidated() async {
    try {
      setState(() => _busy = true);
      final now = Timestamp.now();
      final batch = FirebaseFirestore.instance.batch();

      final trackingRef = FirebaseFirestore.instance.collection('work_order_tracking').doc();
      batch.set(trackingRef, {
        'workOrderNo': widget.workOrderNo,
        'stage': _addressValidatedStage,
        'notes': 'Customer confirmed via link/QR',
        'assignedTo': '',
        'timeLimit': now,
        'createdAt': now,
        'lastUpdated': now,
      });

      final orderRef = FirebaseFirestore.instance.collection('work_orders').doc(widget.orderDocId);
      batch.update(orderRef, {'currentStage': _addressValidatedStage, 'lastUpdated': now});

      await batch.commit();
      if (mounted) _snack('Marked Address validated.');
    } catch (e) {
      if (mounted) _snack('Failed to update: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _moveToFedex() async {
    final ctl = TextEditingController();
    final key = GlobalKey<FormState>();
    final tracking = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter FedEx Tracking Number', style: TextStyle(color: _darkBlue)),
        content: Form(
          key: key,
          child: TextFormField(
            controller: ctl,
            decoration: const InputDecoration(hintText: 'e.g. 1234 5678 9012', border: OutlineInputBorder()),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _darkBlue),
            onPressed: () {
              if (key.currentState?.validate() ?? false) {
                Navigator.pop(ctx, ctl.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (tracking == null) return;

    try {
      setState(() => _busy = true);
      final now = Timestamp.now();
      final batch = FirebaseFirestore.instance.batch();

      final trackingRef = FirebaseFirestore.instance.collection('work_order_tracking').doc();
      batch.set(trackingRef, {
        'workOrderNo': widget.workOrderNo,
        'stage': _finalTrackingStage,
        'notes': 'FedEx: $tracking',
        'assignedTo': '',
        'timeLimit': now,
        'createdAt': now,
        'lastUpdated': now,
        'trackingNo': tracking,
      });

      final orderRef = FirebaseFirestore.instance.collection('work_orders').doc(widget.orderDocId);
      batch.update(orderRef, {'currentStage': _finalTrackingStage, 'lastUpdated': now, 'trackingNo': tracking});

      await batch.commit();
      if (mounted) _snack('Moved to FedEx tracking stage.');
    } catch (e) {
      if (mounted) _snack('Failed to update: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _PromptResult {
  final String email;
  final String message;
  _PromptResult(this.email, this.message);
}

/// —————————————————————————————————————————————————————————————
/// LIVE QR PAGE — shows QR & link; watch status; confirm live now
/// —————————————————————————————————————————————————————————————
class _QrLivePage extends StatelessWidget {
  const _QrLivePage({
    Key? key,
    required this.workOrderNo,
    required this.token,
    required this.url,
    required this.qrPath,
  }) : super(key: key);

  final String workOrderNo;
  final String token;
  final String url;
  final String qrPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _panel,
      appBar: AppBar(title: Text('WO $workOrderNo • QR'), backgroundColor: _darkBlue),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(16),
          child: Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.file(File(qrPath), width: 220, height: 220),
                  const SizedBox(height: 10),
                  SelectableText(url, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 12),
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('address_validations')
                        .doc(token)
                        .snapshots(),
                    builder: (_, snap) {
                      final status = snap.data?.data()?['status'] as String? ?? 'pending';
                      final confirmed = status == 'confirmed';
                      final color = confirmed ? Colors.green : Colors.orange;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(confirmed ? Icons.verified : Icons.hourglass_bottom, color: color),
                          const SizedBox(width: 8),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: confirmed ? Colors.green.shade700 : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.shield_moon_outlined),
                      onPressed: () async {
                        try {
                          final now = Timestamp.now();

                          // Read validation doc to get workOrderId/No
                          final vRef = FirebaseFirestore.instance.collection('address_validations').doc(token);
                          final vSnap = await vRef.get();
                          final data = vSnap.data() ?? {};
                          final workOrderId = (data['workOrderId'] as String?) ?? '';
                          final workOrderNoDoc = (data['workOrderNo'] as String?) ?? '';

                          // Mirror updates (validation + work order)
                          final batch = FirebaseFirestore.instance.batch();
                          batch.update(vRef, {'status': 'confirmed', 'confirmedAt': now});

                          if (workOrderId.isNotEmpty) {
                            final oRef = FirebaseFirestore.instance.collection('work_orders').doc(workOrderId);
                            batch.update(oRef, {
                              'addressValidation.status': 'confirmed',
                              'addressValidation.confirmedAt': now,
                              'lastUpdated': now,
                            });
                          } else if (workOrderNoDoc.isNotEmpty) {
                            final oq = await FirebaseFirestore.instance
                                .collection('work_orders')
                                .where('workOrderNo', isEqualTo: workOrderNoDoc)
                                .limit(1)
                                .get();
                            if (oq.docs.isNotEmpty) {
                              batch.update(oq.docs.first.reference, {
                                'addressValidation.status': 'confirmed',
                                'addressValidation.confirmedAt': now,
                                'lastUpdated': now,
                              });
                            }
                          }

                          await batch.commit();

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Address confirmed live.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Confirm failed: $e')),
                            );
                          }
                        }
                      },
                      label: const Text('Confirm Live Now'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// —————————————————————————————————————————————————————————————
/// HELPERS
/// —————————————————————————————————————————————————————————————
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final MaterialColor base = status == 'confirmed' ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: base.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: base.withOpacity(.35)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: base.shade700, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: .2),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(.25)),
      ),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: _darkBlue)),
          const Spacer(),
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, color: color.shade700)),
        ],
      ),
    );
  }
}

String _makeToken() {
  final rand = Random.secure();
  const alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
  return List.generate(12, (_) => alphabet[rand.nextInt(alphabet.length)]).join();
}

Future<String> _qrPngFile(String data, String filename) async {
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    gapless: true,
    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Colors.black),
  );
  final ui.Image img = await painter.toImage(900);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final bytes = byteData!.buffer.asUint8List();

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}

/// —————————————————————————————————————————————————————————————
/// PUBLIC CONFIRM PAGE — global link (kept for backward compatibility)
/// —————————————————————————————————————————————————————————————
class AddressConfirmPublicPage extends StatefulWidget {
  const AddressConfirmPublicPage({Key? key}) : super(key: key);

  @override
  State<AddressConfirmPublicPage> createState() => _AddressConfirmPublicPageState();
}

class _AddressConfirmPublicPageState extends State<AddressConfirmPublicPage> {
  String? _token;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
    } catch (_) {}
    // Support both /address-confirm?token=... and /#/address-confirm?token=...
    final base = Uri.base;
    String? token = base.queryParameters['token'];
    if (token == null && base.fragment.isNotEmpty) {
      final frag = base.fragment;
      final idx = frag.indexOf('?');
      if (idx != -1 && idx + 1 < frag.length) {
        final qp = Uri.splitQueryString(frag.substring(idx + 1));
        token = qp['token'];
      }
    }
    if (token == null) {
      final segs = base.pathSegments;
      final i = segs.indexOf('address-confirm');
      if (i != -1 && i + 1 < segs.length) token = segs[i + 1];
    }
    setState(() {
      _token = token;
      _ready = true;
    });
  }

  Future<void> _confirm() async {
    if (_token == null) return;
    try {
      final now = Timestamp.now();

      final vRef = FirebaseFirestore.instance.collection('address_validations').doc(_token);
      final vSnap = await vRef.get();
      final data = vSnap.data() ?? {};
      final workOrderId = (data['workOrderId'] as String?) ?? '';
      final workOrderNo = (data['workOrderNo'] as String?) ?? '';

      final batch = FirebaseFirestore.instance.batch();
      batch.update(vRef, {'status': 'confirmed', 'confirmedAt': now});

      if (workOrderId.isNotEmpty) {
        final oRef = FirebaseFirestore.instance.collection('work_orders').doc(workOrderId);
        batch.update(oRef, {
          'addressValidation.status': 'confirmed',
          'addressValidation.confirmedAt': now,
          'lastUpdated': now,
        });
      } else if (workOrderNo.isNotEmpty) {
        final oq = await FirebaseFirestore.instance
            .collection('work_orders')
            .where('workOrderNo', isEqualTo: workOrderNo)
            .limit(1)
            .get();
        if (oq.docs.isNotEmpty) {
          batch.update(oq.docs.first.reference, {
            'addressValidation.status': 'confirmed',
            'addressValidation.confirmedAt': now,
            'lastUpdated': now,
          });
        }
      }

      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! Your address has been confirmed.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not confirm: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_token == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Confirm Address'), backgroundColor: _darkBlue),
        body: const Center(child: Text('Invalid confirmation link.')),
      );
    }
    return Scaffold(
      backgroundColor: _panel,
      appBar: AppBar(title: const Text('Confirm Address'), backgroundColor: _darkBlue),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('address_validations').doc(_token).snapshots(),
            builder: (_, snap) {
              final exists = snap.data?.exists ?? false;
              final data = snap.data?.data();
              final status = (data?['status'] as String?) ?? 'pending';
              final confirmed = status == 'confirmed';

              return Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user, color: _darkBlue, size: 48),
                      const SizedBox(height: 12),
                      const Text(
                        'Confirm your shipping address',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _darkBlue),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        !exists
                            ? 'This confirmation link is invalid or expired.'
                            : confirmed
                            ? 'This order has already been confirmed.'
                            : 'Please tap the button below to confirm your address.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: confirmed ? Colors.grey : Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: (!exists || confirmed) ? null : _confirm,
                          child: Text(confirmed ? 'Already Confirmed' : 'It’s OK — Confirm'),
                        ),
                      ),
                      if (exists) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(confirmed ? Icons.verified : Icons.hourglass_bottom,
                                color: confirmed ? Colors.green : Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: confirmed ? Colors.green.shade700 : Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
