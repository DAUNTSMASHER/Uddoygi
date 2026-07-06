import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

// ── Constants ─────────────────────────────────────────────────────────────
const _primaryGreen = Color(0xFF0A4128);
const _backgroundColor = Color(0xFFF4F7F6);
const _surfaceColor = Color(0xFFFFFFFF);
const _inputFillColor = Color(0xFFF1F5F9);

class SubmitRecommendationPage extends StatefulWidget {
  const SubmitRecommendationPage({Key? key}) : super(key: key);

  @override
  _SubmitRecommendationPageState createState() => _SubmitRecommendationPageState();
}

class _SubmitRecommendationPageState extends State<SubmitRecommendationPage> {
  String _cid = '';
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _govIdController = TextEditingController();
  final _cvController = TextEditingController();
  final _ndaController = TextEditingController();
  final _certsController = TextEditingController();
  final _reasonsController = TextEditingController();

  String _status = 'Approved';

  @override
  void initState() {
    super.initState();
    LocalStorageService.getSavedCompanyId().then((id) {
      if (mounted) setState(() => _cid = id ?? '');
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _govIdController.dispose();
    _cvController.dispose();
    _ndaController.dispose();
    _certsController.dispose();
    _reasonsController.dispose();
    super.dispose();
  }

  Future<void> _sendToCEO() async {
    if (!_formKey.currentState!.validate()) return;
    final data = {
      'fullName': _fullNameController.text.trim(),
      'personalEmail': _emailController.text.trim(),
      'personalPhone': _phoneController.text.trim(),
      'governmentIdUrl': _govIdController.text.trim(),
      'cvUrl': _cvController.text.trim(),
      'ndaUrl': _ndaController.text.trim(),
      'certifications': _certsController.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList(),
      'createdAt': Timestamp.now(),
      'status': _status,
      'reasons': _status == 'Rejected' ? _reasonsController.text.trim() : '',
      'sentToCEO': true,
    };

    await DB.colSync(_cid, C.recommendation).add(data);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recommendation sent to CEO')));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            Transform.translate(
              offset: const Offset(0, -30),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Basic Information'),
                      _buildField(controller: _fullNameController, hint: 'Full Name'),
                      const SizedBox(height: 12),
                      _buildField(controller: _emailController, hint: 'Email'),
                      const SizedBox(height: 12),
                      _buildField(controller: _phoneController, hint: 'Phone'),
                      const SizedBox(height: 24),
                      _sectionLabel('Documents & Certifications'),
                      _buildField(controller: _govIdController, hint: 'Gov\'t ID URL'),
                      const SizedBox(height: 12),
                      _buildField(controller: _cvController, hint: 'CV URL'),
                      const SizedBox(height: 12),
                      _buildField(controller: _ndaController, hint: 'NDA URL'),
                      const SizedBox(height: 12),
                      _buildField(controller: _certsController, hint: 'Certifications (comma separated)'),
                      const SizedBox(height: 24),
                      _sectionLabel('Recommendation Status'),
                      Row(
                        children: [
                          _buildRadio('Approved'),
                          _buildRadio('Rejected'),
                        ],
                      ),
                      if (_status == 'Rejected') ...[
                        const SizedBox(height: 12),
                        _buildField(controller: _reasonsController, hint: 'Rejection Reasons', maxLines: 2),
                      ],
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _sendToCEO,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: Text('Send to CEO', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 160,
      color: _primaryGreen,
      padding: const EdgeInsets.only(top: 60, left: 16, right: 16),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const Spacer(),
              Text('Submit Recommendation', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(text, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF111827))),
    );
  }

  Widget _buildField({required TextEditingController controller, required String hint, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: _inputFillColor, borderRadius: BorderRadius.circular(16)),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.dmSans(color: Colors.grey[500], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildRadio(String value) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _status = value),
        child: Row(
          children: [
            Radio<String>(
              value: value,
              groupValue: _status,
              activeColor: _primaryGreen,
              onChanged: (v) => setState(() => _status = v!),
            ),
            Text(value, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF111827))),
          ],
        ),
      ),
    );
  }
}
