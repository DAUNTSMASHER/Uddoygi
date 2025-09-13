// lib/features/customers/presentation/customer_details.dart
//
// SAFE + VISIBLE DETAILS PAGE (no more blank screen)
// - Spinner while loading
// - "Not found" state if the doc ID is wrong or forbidden by rules
// - Edit / Save with validation
// - Optional country flag chip (uses circle_flags if present)
// - Backward compatible: reads legacy 'address', writes 'address' + 'addressLine'

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Optional: if you added these deps earlier, keep them. If not, you can remove.
import 'package:google_fonts/google_fonts.dart';
import 'package:circle_flags/circle_flags.dart';

class CustomerDetailsPage extends StatefulWidget {
  final String customerId;            // Firestore doc id
  final String? customerEmailHint;    // optional (helps you see who this is)

  const CustomerDetailsPage({
    super.key,
    required this.customerId,
    this.customerEmailHint,
  });

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  final _formKey = GlobalKey<FormState>();

  late final DocumentReference<Map<String, dynamic>> _ref;
  bool _isLoading = true;
  bool _notFound = false;
  bool _isEditing = false;

  // controllers
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController(); // addressLine
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _zip = TextEditingController();
  final _country = TextEditingController();
  final _agentName = TextEditingController();

  String _countryCode = 'UN';
  String _phoneCountryCode = '';

  @override
  void initState() {
    super.initState();
    _ref = FirebaseFirestore.instance.collection('customers').doc(widget.customerId);
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _ref.get();
      if (!snap.exists) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _notFound = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer not found')),
        );
        return;
      }

      final m = snap.data() ?? <String, dynamic>{};
      _name.text = (m['name'] ?? '').toString();
      _email.text = (m['email'] ?? '').toString();
      _phone.text = (m['phone'] ?? '').toString();
      _address.text = (m['addressLine'] ?? m['address'] ?? '').toString();
      _city.text = (m['city'] ?? '').toString();
      _state.text = (m['state'] ?? '').toString();
      _zip.text = (m['zip'] ?? '').toString();
      _country.text = (m['country'] ?? '').toString();
      _agentName.text = (m['agentName'] ?? '').toString();

      _countryCode = (m['countryCode'] ?? 'UN').toString().toUpperCase();
      _phoneCountryCode = (m['phoneCountryCode'] ?? '').toString();

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('CustomerDetails load error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load: $e')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = {
      'name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'phoneCountryCode': _phoneCountryCode,
      'addressLine': _address.text.trim(),
      'address': _address.text.trim(), // keep legacy in sync
      'city': _city.text.trim(),
      'state': _state.text.trim(),
      'zip': _zip.text.trim(),
      'country': _country.text.trim(),
      'countryCode': _countryCode,
      'agentName': _agentName.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _ref.update(payload);
      if (!mounted) return;
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
  }

  Future<void> _deleteCustomer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete customer?'),
        content: const Text('This will permanently remove the customer profile. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _ref.delete();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _zip.dispose();
    _country.dispose();
    _agentName.dispose();
    super.dispose();
  }

  // -------- UI --------

  @override
  Widget build(BuildContext context) {
    final titleStyle = _gf(fontSize: 18, weight: FontWeight.w800);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        actions: [
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteCustomer,
          ),
          if (_isEditing)
            IconButton(
              tooltip: 'Save',
              icon: const Icon(Icons.save_outlined),
              onPressed: _save,
            ),
          IconButton(
            tooltip: _isEditing ? 'Cancel' : 'Edit',
            icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notFound
          ? _notFoundView(context)
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Header
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
                          Text('Profile', style: titleStyle),
                          const Spacer(),
                          _agentChip(),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _field(controller: _name, label: 'Customer Name *', icon: Icons.person_outline, enabled: _isEditing, validator: _req),
                      _field(controller: _email, label: 'Email', icon: Icons.alternate_email, enabled: _isEditing, keyboardType: TextInputType.emailAddress, validator: _emailV),

                      Row(
                        children: [
                          // small dialing code chip (read-only here; keep simple)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.indigo.withOpacity(.06),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.indigo.withOpacity(.2)),
                            ),
                            child: Text(
                              _phoneCountryCode.isEmpty ? '+Code' : '+$_phoneCountryCode',
                              style: _gf(color: Colors.indigo, weight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field(
                              controller: _phone,
                              label: 'Phone Number *',
                              icon: Icons.phone_outlined,
                              enabled: _isEditing,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +()-]'))],
                              validator: _req,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      _field(controller: _address, label: 'Address Line', icon: Icons.location_on_outlined, enabled: _isEditing),

                      Row(
                        children: [
                          Expanded(child: _field(controller: _city, label: 'City', icon: Icons.location_city_outlined, enabled: _isEditing)),
                          const SizedBox(width: 10),
                          Expanded(child: _field(controller: _state, label: 'State / Province', icon: Icons.map_outlined, enabled: _isEditing)),
                        ],
                      ),

                      Row(
                        children: [
                          Expanded(
                            child: _field(
                              controller: _zip,
                              label: 'ZIP / Postal Code',
                              icon: Icons.markunread_mailbox_outlined,
                              enabled: _isEditing,
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _field(
                              controller: _country,
                              label: 'Country *',
                              icon: Icons.public,
                              enabled: _isEditing,
                              validator: _req,
                            ),
                          ),
                        ],
                      ),

                      if (_isEditing) ...[
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.save_outlined),
                            label: Text('Save Changes', style: _gf(weight: FontWeight.w800, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _save,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---- bits ----

  Widget _agentChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.indigo.withOpacity(.2)),
      ),
      child: SizedBox(
        width: 170,
        child: TextFormField(
          controller: _agentName,
          readOnly: !_isEditing,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: 'Agent Name',
            hintStyle: _gf(color: Colors.grey[600]),
          ),
          style: _gf(weight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    IconData? icon,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        validator: validator,
        enabled: enabled,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        style: _gf(weight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: _gf(color: Colors.grey[700], weight: FontWeight.w600),
          filled: true,
          fillColor: const Color(0xFFF7F9FC),
          prefixIcon: icon == null ? null : Icon(icon, color: Colors.indigo),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blueGrey.shade100),
          ),
          disabledBorder: OutlineInputBorder(
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

  // tiny text style helper (works even if google_fonts not installed)
  TextStyle _gf({double? fontSize, FontWeight? weight, Color? color}) {
    final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    try {
      return GoogleFonts.inter(textStyle: base.copyWith(fontSize: fontSize, fontWeight: weight, color: color));
    } catch (_) {
      return base.copyWith(fontSize: fontSize, fontWeight: weight, color: color);
    }
  }

  Widget _notFoundView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 56, color: Colors.blueGrey.shade300),
            const SizedBox(height: 12),
            Text('Customer not found', style: _gf(fontSize: 16, weight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('ID: ${widget.customerId}', style: _gf(color: Colors.blueGrey.shade600)),
          ],
        ),
      ),
    );
  }

  // validators
  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;
  String? _emailV(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim());
    return ok ? null : 'Invalid email';
  }
}
