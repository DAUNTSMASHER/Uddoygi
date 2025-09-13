// lib/features/customers/presentation/add_customer_form.dart
//
// UPDATED FORM (friendly for non-tech users)
// ------------------------------------------------------------
// • Clean card UI with clear labels and gentle spacing
// • Country picker with circular flag (tap to choose)
// • Fields: Name, Email, Phone (with country code), Address Line,
//           City, State/Province, ZIP/Postal Code, Country
// • Saves extra fields to Firestore: countryCode, phoneCountryCode,
//   city, state, zip, addressLine
// • Basic validations (required, email shape, numbers for phone/zip)
//
// Add to pubspec.yaml:
// dependencies:
//   country_picker: ^2.0.20
//   circle_flags: ^3.0.1
//   google_fonts: ^6.2.1
//
// Then: flutter pub get

import 'package:circle_flags/circle_flags.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AddCustomerForm extends StatefulWidget {
  final String userId;
  final String email;

  const AddCustomerForm({
    super.key,
    required this.userId,
    required this.email,
  });

  @override
  State<AddCustomerForm> createState() => _AddCustomerFormState();
}

class _AddCustomerFormState extends State<AddCustomerForm> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();

  late final String _agentName;

  // Country state
  String _countryName = '';
  String _countryCode = 'UN'; // ISO-2 code for circle_flags; "UN" placeholder
  String _phoneCountryCode = ''; // e.g. "1" for USA

  @override
  void initState() {
    super.initState();
    _agentName = _extractAgentName(widget.email);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  String _extractAgentName(String email) {
    final namePart = email.split('@').first;
    return namePart
        .split('.')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      favorite: const ['US', 'GB', 'BD', 'IN', 'CA', 'AU'],
      countryListTheme: CountryListThemeData(
        borderRadius: BorderRadius.circular(16),
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        textStyle: GoogleFonts.inter(),
      ),
      onSelect: (Country c) {
        setState(() {
          _countryName = c.name;
          _countryCode = c.countryCode; // ISO-2
          _phoneCountryCode = c.phoneCode;
          _countryCtrl.text = _countryName;
        });
      },
    );
  }

  Future<void> _addCustomer() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'phoneCountryCode': _phoneCountryCode,
      'addressLine': _addressCtrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      'state': _stateCtrl.text.trim(),
      'zip': _zipCtrl.text.trim(),
      'country': _countryCtrl.text.trim(),
      'countryCode': _countryCode,
      'agentName': _agentName,
      'createdBy': widget.userId,
      'status': 'lead',
      'timestamp': Timestamp.now(),
    };

    await FirebaseFirestore.instance.collection('customers').add(data);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Customer added successfully!')),
    );

    _nameCtrl.clear();
    _emailCtrl.clear();
    _phoneCtrl.clear();
    _addressCtrl.clear();
    _cityCtrl.clear();
    _stateCtrl.clear();
    _zipCtrl.clear();
    _countryCtrl.clear();
    setState(() {
      _countryName = '';
      _countryCode = 'UN';
      _phoneCountryCode = '';
    });
  }

  // ————————————————— UI —————————————————

  @override
  Widget build(BuildContext context) {
    final titleStyle = GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800);
    final labelStyle = GoogleFonts.inter(fontWeight: FontWeight.w600);
    final helperStyle = GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with flag + title
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: ClipOval(
                            child: (_countryCode.length == 2)
                                ? CircleFlag(_countryCode, size: 28)
                                : const Icon(Icons.public, size: 20, color: Colors.indigo),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('Add Customer', style: titleStyle),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(.06),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.indigo.withOpacity(.2)),
                          ),
                          child: Text('Agent: $_agentName', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    _field(
                      controller: _nameCtrl,
                      label: 'Customer Name *',
                      textInputAction: TextInputAction.next,
                      validator: (v) => _req(v),
                      icon: Icons.person_outline,
                    ),

                    _field(
                      controller: _emailCtrl,
                      label: 'Email',
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (v) => _email(v),
                      icon: Icons.alternate_email,
                    ),

                    // Phone with country code chip
                    Row(
                      children: [
                        InkWell(
                          onTap: _pickCountry,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.indigo.withOpacity(.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                (_countryCode.length == 2)
                                    ? CircleFlag(_countryCode, size: 16)
                                    : const Icon(Icons.flag_outlined, size: 14, color: Colors.indigo),
                                const SizedBox(width: 6),
                                Text(
                                  _phoneCountryCode.isEmpty ? '+ Code' : '+$_phoneCountryCode',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: Colors.indigo),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.expand_more, size: 16, color: Colors.indigo),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            controller: _phoneCtrl,
                            label: 'Phone Number *',
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            validator: (v) => _req(v),
                            icon: Icons.phone_outlined,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]'))],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Tap the code to change country', style: helperStyle),

                    const SizedBox(height: 16),

                    _field(
                      controller: _addressCtrl,
                      label: 'Address Line',
                      textInputAction: TextInputAction.next,
                      icon: Icons.location_on_outlined,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _cityCtrl,
                            label: 'City',
                            textInputAction: TextInputAction.next,
                            icon: Icons.location_city_outlined,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _field(
                            controller: _stateCtrl,
                            label: 'State / Province',
                            textInputAction: TextInputAction.next,
                            icon: Icons.map_outlined,
                          ),
                        ),
                      ],
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _zipCtrl,
                            label: 'ZIP / Postal Code',
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            icon: Icons.markunread_mailbox_outlined,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _countryPickerField(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text('Submit', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _addCustomer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ——— Helpers ———

  Widget _countryPickerField() {
    return GestureDetector(
      onTap: _pickCountry,
      child: AbsorbPointer(
        child: _field(
          controller: _countryCtrl,
          label: 'Country *',
          validator: (v) => _req(v),
          icon: Icons.public,
          suffix: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: (_countryCode.length == 2)
                ? CircleFlag(_countryCode, size: 18)
                : const Icon(Icons.flag_outlined, size: 16, color: Colors.indigo),
          ),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    IconData? icon,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, color: Colors.grey[700]),
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          prefixIcon: icon == null ? null : Icon(icon, color: Colors.indigo),
          suffixIcon: suffix,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blueGrey.shade100),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(color: Colors.indigo, width: 1.5),
          ),
        ),
      ),
    );
  }

  String? _req(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _email(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final s = v.trim();
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s);
    return ok ? null : 'Invalid email';
  }
}
