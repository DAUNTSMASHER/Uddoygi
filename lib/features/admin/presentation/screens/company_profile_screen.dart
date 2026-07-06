// lib/features/admin/presentation/screens/company_profile_screen.dart
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uddoygi/services/drive_storage_service.dart';

// ─────────────────────────────────────────────────────────────
// DESIGN TOKENS  (matches the reference design)
// ─────────────────────────────────────────────────────────────
class _C {
  static const bg          = Color(0xFFF5F7FB);
  static const fg          = Color(0xFF0F1724);
  static const card        = Colors.white;
  static const border      = Color(0x14000000);
  static const primary     = Color(0xFF6C0B96);
  static const primaryFg   = Colors.white;
  static const secondary   = Color(0xFFE8F0FF);
  static const secondaryFg = Color(0xFF0B3A66);
  static const muted       = Color(0xFFF1F5F9);
  static const mutedFg     = Color(0xFF667085);
  static const success     = Color(0xFF10B981);
  static const successFg   = Colors.white;
  static const warning     = Color(0xFFF59E0B);
  static const warningFg   = Color(0xFF1F2937);
  static const destructive = Color(0xFFEF4444);
  static const destructiveFg = Colors.white;

  static const rSm = 4.0;
  static const rMd = 6.0;
  static const rLg = 8.0;
  static const rXl = 12.0;
}

// ─────────────────────────────────────────────────────────────
// DATA MODEL
// ─────────────────────────────────────────────────────────────
class _CompanyData {
  String legalName;
  String brandName;
  String businessType;
  String industry;
  String email;
  String phone;
  String website;
  String tradeLicense;
  String incorporationNo;
  String tinBinVat;
  String registeredAddress;
  String factoryAddress;
  bool   factorySameAsRegistered;
  String logoUrl;
  String signatureUrl;
  String sealUrl;
  bool   isVerified;
  List<Map<String, String>> documents;
  String companyId; // 8-digit unique registration ID

  _CompanyData({
    this.legalName              = '',
    this.brandName              = '',
    this.businessType           = 'Private Ltd.',
    this.industry               = '',
    this.email                  = '',
    this.phone                  = '',
    this.website                = '',
    this.tradeLicense           = '',
    this.incorporationNo        = '',
    this.tinBinVat              = '',
    this.registeredAddress      = '',
    this.factoryAddress         = '',
    this.factorySameAsRegistered = false,
    this.logoUrl                = '',
    this.signatureUrl           = '',
    this.sealUrl                = '',
    this.isVerified             = false,
    this.documents              = const [],
    this.companyId              = '',
  });

  factory _CompanyData.fromMap(Map<String, dynamic> m) {
    // 'legalName' may be stored as 'companyName' by the registration screen
    final legalName = (m['legalName'] as String?)?.trim().isNotEmpty == true
        ? m['legalName'] as String
        : (m['companyName'] as String?) ?? '';
    // 'brandName' falls back to legalName if not set separately
    final brandName = (m['brandName'] as String?)?.trim().isNotEmpty == true
        ? m['brandName'] as String
        : legalName;

    return _CompanyData(
      legalName:               legalName,
      brandName:               brandName,
      businessType:            m['businessType']           ?? 'Private Ltd.',
      industry:                m['industry']               ?? '',
      email:                   m['email']                  ?? '',
      phone:                   m['phone']                  ?? '',
      website:                 m['website']                ?? '',
      tradeLicense:            m['tradeLicense']           ?? '',
      incorporationNo:         m['incorporationNo']        ?? '',
      tinBinVat:               m['tinBinVat']              ?? '',
      registeredAddress:       (m['registeredAddress'] as String?)?.trim().isNotEmpty == true
          ? m['registeredAddress'] as String
          : (m['address'] as String?) ?? '',
      factoryAddress:          m['factoryAddress']         ?? '',
      factorySameAsRegistered: m['factorySameAsRegistered'] ?? false,
      logoUrl:                 m['logoUrl']                ?? '',
      signatureUrl:            m['signatureUrl']           ?? '',
      sealUrl:                 m['sealUrl']                ?? '',
      isVerified:              m['isVerified']             ?? false,
      documents:               (m['documents'] as List<dynamic>? ?? [])
          .map((e) => Map<String, String>.from(e as Map))
          .toList(),
      companyId:               m['companyId']              ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'legalName':               legalName,
    'brandName':               brandName,
    'businessType':            businessType,
    'industry':                industry,
    'email':                   email,
    'phone':                   phone,
    'website':                 website,
    'tradeLicense':            tradeLicense,
    'incorporationNo':         incorporationNo,
    'tinBinVat':               tinBinVat,
    'registeredAddress':       registeredAddress,
    'factoryAddress':          factoryAddress,
    'factorySameAsRegistered': factorySameAsRegistered,
    'logoUrl':                 logoUrl,
    'signatureUrl':            signatureUrl,
    'sealUrl':                 sealUrl,
    'isVerified':              isVerified,
    'documents':               documents,
    'companyId':               companyId,
    'updatedAt':               FieldValue.serverTimestamp(),
  };

  int get completionPercent {
    final fields = [
      legalName, brandName, businessType, industry,
      email, phone, website, tradeLicense, incorporationNo,
      tinBinVat, registeredAddress,
    ];
    final filled = fields.where((f) => f.trim().isNotEmpty).length;
    return ((filled / fields.length) * 100).round();
  }
}

// ─────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────
class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});
  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

enum _Tab { overview, legal, address, contacts, banking, documents }

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  String _cid = '';
  static const _docId = 'main';

  _Tab         _tab      = _Tab.overview;
  bool         _loading  = true;
  bool         _saving   = false;
  bool         _editing       = false;
  bool         _uploadingLogo = false;
  double?      _uploadProgress; // null = not uploading, 0..1 = in progress
  _CompanyData _data     = _CompanyData();
  _CompanyData _draft    = _CompanyData();

  // Controllers for editable fields
  late final Map<String, TextEditingController> _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = {
      'brandName':          TextEditingController(),
      'businessType':       TextEditingController(),
      'industry':           TextEditingController(),
      'email':              TextEditingController(),
      'phone':              TextEditingController(),
      'website':            TextEditingController(),
      'incorporationNo':    TextEditingController(),
      'tinBinVat':          TextEditingController(),
      'registeredAddress':  TextEditingController(),
      'factoryAddress':     TextEditingController(),
    };
    _init();
  }

  /// Load company ID first, then fetch profile data sequentially.
  Future<void> _init() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (!mounted) return;
    setState(() => _cid = id ?? '');
    await _load();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) c.dispose();
    super.dispose();
  }

  /// Generates a cryptographically random 8-digit numeric ID.
  static String _generateCompanyId() {
    final rng = Random.secure();
    // Ensure it is always exactly 8 digits (10000000 – 99999999)
    return (10000000 + rng.nextInt(90000000)).toString();
  }

  Future<void> _load() async {
    if (_cid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      // Primary source: data/{cid}/company_profile/main
      final snap = await DB.colSync(_cid, C.companyProfile).doc(_docId).get();
      if (snap.exists && snap.data() != null) {
        _data = _CompanyData.fromMap(snap.data()!);
      } else {
        // Fallback: read from root-level companies/{cid} (written at registration)
        final rootSnap = await DB.companiesCol.doc(_cid).get();
        if (rootSnap.exists && rootSnap.data() != null) {
          _data = _CompanyData.fromMap(rootSnap.data()!);
          // Backfill the company_profile/main document so future loads are fast
          await DB.colSync(_cid, C.companyProfile).doc(_docId).set(
            _data.toMap()..remove('updatedAt'),
            SetOptions(merge: true),
          );
        }
      }
      // Auto-generate and persist a company ID if one doesn't exist yet
      if (_data.companyId.isEmpty) {
        final newId = _generateCompanyId();
        _data.companyId = newId;
        await DB.colSync(_cid, C.companyProfile).doc(_docId).set(
          {'companyId': newId}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[CompanyProfile] _load error: $e');
    }
    _syncDraftFromData();
    if (mounted) setState(() => _loading = false);
  }

  void _syncDraftFromData() {
    _draft = _CompanyData.fromMap(_data.toMap()
      ..remove('updatedAt'));
    _ctrl['brandName']!.text         = _data.brandName;
    _ctrl['businessType']!.text      = _data.businessType;
    _ctrl['industry']!.text          = _data.industry;
    _ctrl['email']!.text             = _data.email;
    _ctrl['phone']!.text             = _data.phone;
    _ctrl['website']!.text           = _data.website;
    _ctrl['incorporationNo']!.text   = _data.incorporationNo;
    _ctrl['tinBinVat']!.text         = _data.tinBinVat;
    _ctrl['registeredAddress']!.text = _data.registeredAddress;
    _ctrl['factoryAddress']!.text    = _data.factoryAddress;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // Collect from controllers
      _draft.brandName          = _ctrl['brandName']!.text.trim();
      _draft.businessType       = _ctrl['businessType']!.text.trim();
      _draft.industry           = _ctrl['industry']!.text.trim();
      _draft.email              = _ctrl['email']!.text.trim();
      _draft.phone              = _ctrl['phone']!.text.trim();
      _draft.website            = _ctrl['website']!.text.trim();
      _draft.incorporationNo    = _ctrl['incorporationNo']!.text.trim();
      _draft.tinBinVat          = _ctrl['tinBinVat']!.text.trim();
      _draft.registeredAddress  = _ctrl['registeredAddress']!.text.trim();
      _draft.factoryAddress     = _ctrl['factoryAddress']!.text.trim();

      await DB.colSync(_cid, C.companyProfile).doc(_docId).set(
        _draft.toMap(), SetOptions(merge: true));

      _data = _CompanyData.fromMap(_draft.toMap()..remove('updatedAt'));
      if (mounted) {
        setState(() { _editing = false; _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company profile saved successfully.')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')));
      }
    }
  }

  void _cancelEdit() {
    _syncDraftFromData();
    setState(() { _editing = false; _draft = _CompanyData.fromMap(_data.toMap()..remove('updatedAt')); });
  }

  Future<void> _pickLogo() async {
    if (_cid.isEmpty) return;
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85, maxWidth: 512, maxHeight: 512);
      if (xFile == null || !mounted) return;

      setState(() { _uploadingLogo = true; _uploadProgress = 0; });
      
      final result = await DriveStorageService.instance.uploadFile(
        File(xFile.path),
        pathPrefix: 'company_logo',
        customName: '$_cid logo.jpg',
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p.clamp(0.0, 1.0));
        },
      );
      final url = result.viewUrl;

      await DB.colSync(_cid, C.companyProfile)
          .doc(_docId)
          .set({'logoUrl': url}, SetOptions(merge: true));

      if (mounted) {
        setState(() {
          _data.logoUrl  = url;
          _draft.logoUrl = url;
          _uploadingLogo = false;
          _uploadProgress = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo uploaded successfully'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() { _uploadingLogo = false; _uploadProgress = null; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _pickAsset(String field) async {
    if (_cid.isEmpty) return;
    try {
      final picker = ImagePicker();
      final xFile = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85, maxWidth: 1024);
      if (xFile == null || !mounted) return;

      // Show a brief uploading snack
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Uploading ${field == 'signatureUrl' ? 'signature' : 'seal'}…'),
          ]),
          duration: const Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
        ),
      );

      final result = await DriveStorageService.instance.uploadFile(
        File(xFile.path),
        pathPrefix: 'company_$field',
        customName: '$_cid $field.jpg',
      );
      final url = result.viewUrl;

      await DB.colSync(_cid, C.companyProfile)
          .doc(_docId)
          .set({field: url}, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() {
          if (field == 'signatureUrl') { _data.signatureUrl = url; _draft.signatureUrl = url; }
          if (field == 'sealUrl')      { _data.sealUrl      = url; _draft.sealUrl      = url; }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Asset uploaded successfully'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  // ── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _C.bg,
        body: Center(child: CircularProgressIndicator(color: _C.primary)),
      );
    }

    final pct = _data.completionPercent;
    final missingTin = _data.tinBinVat.trim().isEmpty;

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App Bar ──
            _AppBar(
              editing: _editing,
              onBack: () => Navigator.maybePop(context),
              onEdit: () => setState(() => _editing = true),
            ),
            // ── Scrollable body ──
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // ── Top block: avatar + name + tabs ──
                  _TopBlock(
                    data: _data,
                    pct: pct,
                    tab: _tab,
                    onTabChanged: (t) => setState(() => _tab = t),
                    onPickLogo: _pickLogo,
                    companyId: _data.companyId,
                    uploadingLogo: _uploadingLogo,
                    uploadProgress: _uploadProgress,
                  ),
                  // ── Alert banner ──
                  if (missingTin) ...[
                    const SizedBox(height: 8),
                    _AlertBanner(
                      message: 'TIN / BIN / VAT number is required. '
                          'Ensure all fields are updated to avoid suspension.',
                    ),
                  ],
                  const SizedBox(height: 8),
                  // ── Tab content ──
                  _TabContent(
                    tab: _tab,
                    data: _data,
                    draft: _draft,
                    ctrl: _ctrl,
                    editing: _editing,
                    companyId: _data.companyId,
                    onToggleFactory: (v) => setState(() => _draft.factorySameAsRegistered = v),
                    onPickAsset: _pickAsset,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
            // ── Bottom bar ──
            _BottomBar(
              editing: _editing,
              saving: _saving,
              onCancel: _cancelEdit,
              onSave: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// APP BAR
// ─────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget {
  final bool editing;
  final VoidCallback onBack, onEdit;
  const _AppBar({required this.editing, required this.onBack, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: _C.card,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back_rounded, size: 22, color: _C.fg),
          ),
          const Expanded(
            child: Text('My Company',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                    color: _C.fg)),
          ),
          if (!editing)
            GestureDetector(
              onTap: onEdit,
              child: const Text('Edit',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: _C.primary)),
            )
          else
            const SizedBox(width: 32),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TOP BLOCK (avatar + name + progress + tabs)
// ─────────────────────────────────────────────────────────────
class _TopBlock extends StatelessWidget {
  final _CompanyData data;
  final int          pct;
  final _Tab         tab;
  final ValueChanged<_Tab> onTabChanged;
  final VoidCallback onPickLogo;
  final String       companyId;
  final bool         uploadingLogo;
  final double?      uploadProgress;

  const _TopBlock({
    required this.data,
    required this.pct,
    required this.tab,
    required this.onTabChanged,
    required this.onPickLogo,
    required this.companyId,
    this.uploadingLogo  = false,
    this.uploadProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.card,
      child: Column(
        children: [
          // Profile header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
            child: Column(
              children: [
                // Avatar with real-time upload progress ring
                GestureDetector(
                  onTap: uploadingLogo ? null : onPickLogo,
                  child: SizedBox(
                    width: 80, height: 80,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Progress ring (shown while uploading)
                        if (uploadingLogo)
                          SizedBox(
                            width: 80, height: 80,
                            child: CircularProgressIndicator(
                              value: uploadProgress,
                              strokeWidth: 3,
                              backgroundColor: _C.muted,
                              valueColor: const AlwaysStoppedAnimation(_C.primary),
                            ),
                          ),
                        // Logo circle
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _C.muted,
                            border: Border.all(
                              color: uploadingLogo ? _C.primary : _C.border,
                              width: uploadingLogo ? 2 : 1,
                            ),
                            image: data.logoUrl.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(data.logoUrl),
                                    fit: BoxFit.cover,
                                    colorFilter: uploadingLogo
                                        ? ColorFilter.mode(
                                            Colors.white.withValues(alpha: 0.5),
                                            BlendMode.lighten)
                                        : null,
                                  )
                                : null,
                          ),
                          child: uploadingLogo
                              ? const Icon(Icons.cloud_upload_rounded,
                                  size: 28, color: _C.primary)
                              : data.logoUrl.isEmpty
                                  ? const Icon(Icons.business_rounded,
                                      size: 32, color: _C.primary)
                                  : null,
                        ),
                        // Camera badge (hidden while uploading)
                        if (!uploadingLogo)
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              width: 26, height: 26,
                              decoration: BoxDecoration(
                                color: _C.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: _C.card, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded,
                                  size: 12, color: _C.primaryFg),
                            ),
                          ),
                        // % label while uploading
                        if (uploadingLogo && uploadProgress != null)
                          Text(
                            '${(uploadProgress! * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _C.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Company name
                Text(
                  data.legalName.isNotEmpty ? data.legalName : 'Your Company',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600,
                      color: _C.fg),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                // Badges
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (data.isVerified) ...[
                    _SmallBadge(Icons.verified_rounded, 'Verified', _C.success, _C.successFg),
                    const SizedBox(width: 8),
                  ],
                  if (data.industry.isNotEmpty)
                    _SmallBadge(null, data.industry, _C.muted, _C.mutedFg, border: true),
                ]),
                const SizedBox(height: 16),
                // ── Company ID badge ──────────────────────────
                if (companyId.isNotEmpty)
                  _CompanyIdBadge(companyId: companyId),
                const SizedBox(height: 16),
                // Completion bar
                SizedBox(
                  width: 280,
                  child: Column(children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Profile Completion',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                                color: _C.mutedFg)),
                        Text('$pct%',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                color: _C.primary)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct / 100,
                        minHeight: 6,
                        backgroundColor: _C.muted,
                        valueColor: const AlwaysStoppedAnimation(_C.primary),
                      ),
                    ),
                  ]),
                ),
              ],
            ),
          ),
          // Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: _Tab.values.map((t) {
                final active = t == tab;
                final labels = {
                  _Tab.overview:  'Overview',
                  _Tab.legal:     'Legal Info',
                  _Tab.address:   'Address',
                  _Tab.contacts:  'Contacts',
                  _Tab.banking:   'Banking',
                  _Tab.documents: 'Documents',
                };
                return GestureDetector(
                  onTap: () => onTabChanged(t),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: active ? _C.primary : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(labels[t]!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: active ? _C.primary : _C.mutedFg,
                        )),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ALERT BANNER
// ─────────────────────────────────────────────────────────────
class _AlertBanner extends StatelessWidget {
  final String message;
  const _AlertBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          border: Border.all(color: const Color(0xFFFDE68A)),
          borderRadius: BorderRadius.circular(_C.rLg),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.warning_amber_rounded,
              size: 20, color: Color(0xFFD97706)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Missing Compliance Info',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E))),
              const SizedBox(height: 4),
              Text(message,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB45309),
                      height: 1.4)),
            ],
          )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB CONTENT DISPATCHER
// ─────────────────────────────────────────────────────────────
class _TabContent extends StatelessWidget {
  final _Tab   tab;
  final _CompanyData data, draft;
  final Map<String, TextEditingController> ctrl;
  final bool   editing;
  final String companyId;
  final ValueChanged<bool> onToggleFactory;
  final Future<void> Function(String) onPickAsset;

  const _TabContent({
    required this.tab,
    required this.data,
    required this.draft,
    required this.ctrl,
    required this.editing,
    required this.companyId,
    required this.onToggleFactory,
    required this.onPickAsset,
  });

  @override
  Widget build(BuildContext context) {
    switch (tab) {
      case _Tab.overview:
        return _OverviewTab(ctrl: ctrl, data: data, editing: editing, companyId: companyId);
      case _Tab.legal:
        return _LegalTab(ctrl: ctrl, data: data, editing: editing);
      case _Tab.address:
        return _AddressTab(
            ctrl: ctrl, draft: draft, editing: editing,
            onToggle: onToggleFactory);
      case _Tab.contacts:
        return _ContactsTab(ctrl: ctrl, editing: editing);
      case _Tab.banking:
        return _BankingTab(data: data);
      case _Tab.documents:
        return _DocumentsTab(data: data, onPickAsset: onPickAsset);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// TAB: OVERVIEW
// ─────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final Map<String, TextEditingController> ctrl;
  final _CompanyData data;
  final bool editing;
  final String companyId;
  const _OverviewTab({required this.ctrl, required this.data, required this.editing, required this.companyId});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Company Identity',
      children: [
        // Company ID — always shown at the top, read-only
        if (companyId.isNotEmpty) _CompanyIdCard(companyId: companyId),
        _LockedField(label: 'Legal Company Name', value: data.legalName),
        _EditableField(label: 'Brand Name', ctrl: ctrl['brandName']!, editing: editing),
        Row(children: [
          Expanded(child: _DropdownField(
            label: 'Business Type',
            ctrl: ctrl['businessType']!,
            editing: editing,
            options: const ['Private Ltd.', 'Public Ltd.', 'Partnership', 'Sole Proprietorship', 'OPC'],
          )),
          const SizedBox(width: 12),
          Expanded(child: _DropdownField(
            label: 'Industry',
            ctrl: ctrl['industry']!,
            editing: editing,
            options: const ['Manufacturing', 'Electronics', 'Textile', 'IT', 'Retail', 'Healthcare', 'Other'],
          )),
        ]),
        _EditableField(label: 'Official Email', ctrl: ctrl['email']!, editing: editing,
            keyboardType: TextInputType.emailAddress),
        _PhoneFieldWithBadge(ctrl: ctrl['phone']!, editing: editing),
        _EditableField(label: 'Website', ctrl: ctrl['website']!, editing: editing,
            keyboardType: TextInputType.url),
      ],
    );
  }
}

// Phone field with security badge shown when editing
class _PhoneFieldWithBadge extends StatelessWidget {
  final TextEditingController ctrl;
  final bool editing;
  const _PhoneFieldWithBadge({required this.ctrl, required this.editing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Text('Contact Phone',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: _C.mutedFg)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFFCD34D)),
            ),
            child: const Text('Used for OTP',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E))),
          ),
        ]),
        const SizedBox(height: 6),
        editing
            ? TextFormField(
                controller: ctrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: _C.fg),
                decoration: InputDecoration(
                  hintText: '+8801XXXXXXXXX',
                  hintStyle: const TextStyle(fontSize: 13, color: _C.mutedFg),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: _C.muted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_C.rLg),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(_C.rLg),
                    borderSide: const BorderSide(color: _C.primary),
                  ),
                ),
              )
            : Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _C.muted,
                  borderRadius: BorderRadius.circular(_C.rLg),
                ),
                child: Text(
                  ctrl.text.isNotEmpty ? ctrl.text : '—',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                      color: _C.fg),
                ),
              ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB: LEGAL
// ─────────────────────────────────────────────────────────────
class _LegalTab extends StatelessWidget {
  final Map<String, TextEditingController> ctrl;
  final _CompanyData data;
  final bool editing;
  const _LegalTab({required this.ctrl, required this.data, required this.editing});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Legal & Compliance',
      children: [
        Row(children: [
          Expanded(child: _LockedField(label: 'Trade License', value: data.tradeLicense)),
          const SizedBox(width: 12),
          Expanded(child: _EditableField(
              label: 'Incorporation No.', ctrl: ctrl['incorporationNo']!, editing: editing)),
        ]),
        _RequiredField(
          label: 'TIN / BIN / VAT No.',
          ctrl: ctrl['tinBinVat']!,
          editing: editing,
          missing: data.tinBinVat.trim().isEmpty,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB: ADDRESS
// ─────────────────────────────────────────────────────────────
class _AddressTab extends StatelessWidget {
  final Map<String, TextEditingController> ctrl;
  final _CompanyData draft;
  final bool editing;
  final ValueChanged<bool> onToggle;
  const _AddressTab({required this.ctrl, required this.draft,
      required this.editing, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Location Details',
      children: [
        _EditableField(label: 'Registered Address', ctrl: ctrl['registeredAddress']!,
            editing: editing, maxLines: 3),
        _ToggleRow(
          label: 'Factory Address same as registered',
          value: draft.factorySameAsRegistered,
          onChanged: editing ? onToggle : null,
        ),
        if (!draft.factorySameAsRegistered)
          _EditableField(label: 'Factory Address', ctrl: ctrl['factoryAddress']!,
              editing: editing, maxLines: 3),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB: CONTACTS
// ─────────────────────────────────────────────────────────────
class _ContactsTab extends StatelessWidget {
  final Map<String, TextEditingController> ctrl;
  final bool editing;
  const _ContactsTab({required this.ctrl, required this.editing});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Contact Information',
      children: [
        _EditableField(label: 'Official Email', ctrl: ctrl['email']!, editing: editing,
            keyboardType: TextInputType.emailAddress),
        _EditableField(label: 'Contact Phone', ctrl: ctrl['phone']!, editing: editing,
            keyboardType: TextInputType.phone),
        // Security notice
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(_C.rLg),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.security_rounded, size: 16, color: Color(0xFFD97706)),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Used for Data Reset Verification',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                        color: Color(0xFF92400E))),
                SizedBox(height: 3),
                Text(
                  'This phone number will be used to send an OTP when resetting, '
                  'backing up, or importing data in Admin Settings. '
                  'Keep it accurate and in international format (e.g. +8801XXXXXXXXX).',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB45309), height: 1.45),
                ),
              ]),
            ),
          ]),
        ),
        _EditableField(label: 'Website', ctrl: ctrl['website']!, editing: editing,
            keyboardType: TextInputType.url),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB: BANKING (read-only placeholder — extend as needed)
// ─────────────────────────────────────────────────────────────
class _BankingTab extends StatelessWidget {
  final _CompanyData data;
  const _BankingTab({required this.data});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Banking Information',
      children: [
        _InfoRow(icon: Icons.account_balance_rounded, label: 'Bank Account',
            value: 'Not configured'),
        _InfoRow(icon: Icons.credit_card_rounded, label: 'Routing / SWIFT',
            value: 'Not configured'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _C.secondary.withOpacity(0.5),
            borderRadius: BorderRadius.circular(_C.rLg),
            border: Border.all(color: _C.primary.withOpacity(0.15)),
          ),
          child: Row(children: [
            const Icon(Icons.info_outline_rounded, size: 16, color: _C.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text(
              'Banking details can be configured by contacting your system administrator.',
              style: TextStyle(fontSize: 12, color: _C.mutedFg),
            )),
          ]),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TAB: DOCUMENTS + BRANDING ASSETS
// ─────────────────────────────────────────────────────────────
class _DocumentsTab extends StatelessWidget {
  final _CompanyData data;
  final Future<void> Function(String) onPickAsset;
  const _DocumentsTab({required this.data, required this.onPickAsset});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Branding assets
        _SectionCard(
          title: 'Branding Assets',
          children: [
            _AssetRow(
              label: 'Digital Signature',
              meta: data.signatureUrl.isNotEmpty ? 'Uploaded' : 'Not uploaded',
              uploaded: data.signatureUrl.isNotEmpty,
              onUpload: () => onPickAsset('signatureUrl'),
            ),
            _AssetRow(
              label: 'Company Seal',
              meta: data.sealUrl.isNotEmpty ? 'Uploaded' : 'Not uploaded',
              uploaded: data.sealUrl.isNotEmpty,
              onUpload: () => onPickAsset('sealUrl'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Documents list
        _SectionCard(
          title: 'Company Documents',
          children: [
            _DocItem(
              icon: Icons.description_rounded,
              title: 'Trade License',
              meta: data.tradeLicense.isNotEmpty
                  ? 'License: ${data.tradeLicense}'
                  : 'Not uploaded',
              valid: data.tradeLicense.isNotEmpty,
            ),
            _DocItem(
              icon: Icons.business_rounded,
              title: 'Incorporation Certificate',
              meta: data.incorporationNo.isNotEmpty
                  ? 'No: ${data.incorporationNo}'
                  : 'Not uploaded',
              valid: data.incorporationNo.isNotEmpty,
            ),
            if (data.documents.isNotEmpty)
              ...data.documents.map((doc) => _DocItem(
                icon: Icons.attach_file_rounded,
                title: doc['name'] ?? 'Document',
                meta:  doc['meta'] ?? '',
                valid: true,
              )),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// BOTTOM BAR
// ─────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final bool editing, saving;
  final VoidCallback onCancel, onSave;
  const _BottomBar({required this.editing, required this.saving,
      required this.onCancel, required this.onSave});

  @override
  Widget build(BuildContext context) {
    if (!editing) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: _C.card,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      child: Row(children: [
        // Cancel
        Expanded(
          child: GestureDetector(
            onTap: onCancel,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _C.card,
                border: Border.all(color: _C.border),
                borderRadius: BorderRadius.circular(_C.rLg),
              ),
              alignment: Alignment.center,
              child: const Text('Cancel',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: _C.fg)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Save Changes
        Expanded(
          child: GestureDetector(
            onTap: saving ? null : onSave,
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _C.primary,
                borderRadius: BorderRadius.circular(_C.rLg),
              ),
              alignment: Alignment.center,
              child: saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                          color: _C.primaryFg)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COMPANY ID — hero badge (shown in top block)
// ─────────────────────────────────────────────────────────────
class _CompanyIdBadge extends StatelessWidget {
  final String companyId;
  const _CompanyIdBadge({required this.companyId});

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: companyId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Company ID copied to clipboard'),
        backgroundColor: _C.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Format as "1234 5678" for readability
    final formatted = companyId.length == 8
        ? '${companyId.substring(0, 4)} ${companyId.substring(4)}'
        : companyId;

    return GestureDetector(
      onTap: () => _copy(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C0B96), Color(0xFF9333EA)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(99),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C0B96).withOpacity(.28),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fingerprint_rounded, size: 15, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              'ID  $formatted',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.copy_rounded, size: 13, color: Colors.white60),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COMPANY ID — full card (shown in Overview tab)
// ─────────────────────────────────────────────────────────────
class _CompanyIdCard extends StatelessWidget {
  final String companyId;
  const _CompanyIdCard({required this.companyId});

  void _copy(BuildContext context) {
    Clipboard.setData(ClipboardData(text: companyId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Company ID copied to clipboard'),
        backgroundColor: _C.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatted = companyId.length == 8
        ? '${companyId.substring(0, 4)} ${companyId.substring(4)}'
        : companyId;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B0764), Color(0xFF6C0B96)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_C.rXl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C0B96).withOpacity(.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.fingerprint_rounded,
                    size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Company Registration ID',
                        style: TextStyle(fontSize: 11, color: Colors.white60,
                            fontWeight: FontWeight.w600)),
                    Text('System-generated · Read only',
                        style: TextStyle(fontSize: 10, color: Colors.white38)),
                  ],
                ),
              ),
              // Verified chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: Colors.white24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 11, color: Color(0xFF86EFAC)),
                    SizedBox(width: 4),
                    Text('Registered', style: TextStyle(fontSize: 10,
                        color: Color(0xFF86EFAC), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ID display
          Row(
            children: [
              Expanded(
                child: Text(
                  formatted,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Divider
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 10),
          // Actions row
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 12, color: Colors.white38),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Use this ID to verify your company registration in the system.',
                  style: TextStyle(fontSize: 10, color: Colors.white54, height: 1.4),
                ),
              ),
              const SizedBox(width: 8),
              // Copy button
              GestureDetector(
                onTap: () => _copy(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 13, color: Colors.white),
                      SizedBox(width: 5),
                      Text('Copy ID',
                          style: TextStyle(fontSize: 11, color: Colors.white,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// REUSABLE FORM WIDGETS
// ─────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(
        color: _C.card,
        border: Border.symmetric(
          horizontal: BorderSide(color: _C.border),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600,
                  color: _C.fg)),
          const SizedBox(height: 16),
          ...children.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: w,
          )),
        ],
      ),
    );
  }
}

class _LockedField extends StatelessWidget {
  final String label, value;
  const _LockedField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
            color: _C.mutedFg)),
        const SizedBox(width: 4),
        const Icon(Icons.lock_outline_rounded, size: 12, color: _C.mutedFg),
      ]),
      const SizedBox(height: 6),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _C.card,
          border: Border.all(color: _C.border, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(_C.rLg),
        ),
        child: Text(
          value.isNotEmpty ? value : '—',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
              color: _C.mutedFg),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ]);
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool editing;
  final TextInputType keyboardType;
  final int maxLines;
  const _EditableField({
    required this.label,
    required this.ctrl,
    required this.editing,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
          color: _C.mutedFg)),
      const SizedBox(height: 6),
      editing
          ? TextFormField(
              controller: ctrl,
              keyboardType: keyboardType,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                  color: _C.fg),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                filled: true,
                fillColor: _C.muted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_C.rLg),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_C.rLg),
                  borderSide: const BorderSide(color: _C.primary),
                ),
              ),
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _C.muted,
                borderRadius: BorderRadius.circular(_C.rLg),
              ),
              child: Text(
                ctrl.text.isNotEmpty ? ctrl.text : '—',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                    color: _C.fg),
                overflow: TextOverflow.ellipsis,
                maxLines: maxLines,
              ),
            ),
    ]);
  }
}

class _RequiredField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool editing, missing;
  const _RequiredField({required this.label, required this.ctrl,
      required this.editing, required this.missing});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
            color: _C.mutedFg)),
        const Spacer(),
        if (missing)
          const Text('Required',
              style: TextStyle(fontSize: 11, color: _C.destructive,
                  fontWeight: FontWeight.w600)),
      ]),
      const SizedBox(height: 6),
      editing
          ? TextFormField(
              controller: ctrl,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                  color: _C.fg),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                filled: true,
                fillColor: missing
                    ? _C.destructive.withOpacity(0.05)
                    : _C.muted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_C.rLg),
                  borderSide: missing
                      ? const BorderSide(color: _C.destructive, width: 0.5)
                      : BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_C.rLg),
                  borderSide: missing
                      ? BorderSide(color: _C.destructive.withOpacity(0.4))
                      : BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(_C.rLg),
                  borderSide: const BorderSide(color: _C.primary),
                ),
              ),
            )
          : Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: missing
                    ? _C.destructive.withOpacity(0.05)
                    : _C.muted,
                borderRadius: BorderRadius.circular(_C.rLg),
                border: missing
                    ? Border.all(color: _C.destructive.withOpacity(0.3))
                    : null,
              ),
              child: Text(
                ctrl.text.isNotEmpty ? ctrl.text : 'Not provided',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500,
                  color: missing ? _C.destructive : _C.fg,
                ),
              ),
            ),
    ]);
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool editing;
  final List<String> options;
  const _DropdownField({required this.label, required this.ctrl,
      required this.editing, required this.options});

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      return _EditableField(label: label, ctrl: ctrl, editing: false);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
          color: _C.mutedFg)),
      const SizedBox(height: 6),
      DropdownButtonFormField<String>(
        value: options.contains(ctrl.text) ? ctrl.text : null,
        onChanged: (v) { if (v != null) ctrl.text = v; },
        items: options.map((o) => DropdownMenuItem(value: o, child: Text(o,
            style: const TextStyle(fontSize: 14)))).toList(),
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          filled: true,
          fillColor: _C.muted,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_C.rLg),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(_C.rLg),
            borderSide: const BorderSide(color: _C.primary),
          ),
        ),
        style: const TextStyle(fontSize: 14, color: _C.fg),
        dropdownColor: _C.card,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _C.mutedFg),
      ),
    ]);
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  const _ToggleRow({required this.label, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                color: _C.fg))),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _C.success,
          inactiveThumbColor: _C.mutedFg,
          inactiveTrackColor: _C.muted,
        ),
      ],
    );
  }
}

class _AssetRow extends StatelessWidget {
  final String label, meta;
  final bool uploaded;
  final VoidCallback onUpload;
  const _AssetRow({required this.label, required this.meta,
      required this.uploaded, required this.onUpload});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: uploaded ? _C.muted : _C.card,
        border: uploaded
            ? null
            : Border.all(color: _C.border, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(_C.rLg),
      ),
      child: Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w500, color: _C.fg)),
            const SizedBox(height: 2),
            Text(meta, style: const TextStyle(fontSize: 12, color: _C.mutedFg)),
          ],
        )),
        uploaded
            ? const Icon(Icons.check_circle_rounded,
                size: 20, color: _C.success)
            : GestureDetector(
                onTap: onUpload,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _C.secondary,
                    borderRadius: BorderRadius.circular(_C.rSm),
                  ),
                  child: const Text('Upload',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: _C.primary)),
                ),
              ),
      ]),
    );
  }
}

class _DocItem extends StatelessWidget {
  final IconData icon;
  final String   title, meta;
  final bool     valid;
  const _DocItem({required this.icon, required this.title,
      required this.meta, required this.valid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.card,
        border: Border.all(color: _C.border),
        borderRadius: BorderRadius.circular(_C.rLg),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _C.secondary,
            borderRadius: BorderRadius.circular(_C.rSm),
          ),
          child: Icon(icon, size: 18, color: _C.primary),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w500, color: _C.fg)),
            Text(meta, style: const TextStyle(fontSize: 12, color: _C.mutedFg)),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: valid ? _C.success : _C.muted,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            valid ? 'Valid' : 'Missing',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                color: valid ? _C.successFg : _C.mutedFg),
          ),
        ),
      ]),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  final IconData? icon;
  final String    label;
  final Color     bg, fg;
  final bool      border;
  const _SmallBadge(this.icon, this.label, this.bg, this.fg, {this.border = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: border ? Border.all(color: _C.border) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
        ],
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: fg)),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.muted,
        borderRadius: BorderRadius.circular(_C.rLg),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: _C.primary),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: _C.mutedFg)),
            Text(value, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w500, color: _C.fg)),
          ],
        )),
      ]),
    );
  }
}
