import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();

  late final String _agentName;

  @override
  void initState() {
    super.initState();
    _agentName = _extractAgentName(widget.email);
  }

  String _extractAgentName(String email) {
    final namePart = email.split('@')[0];
    return namePart
        .split('.')
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  Future<void> _addCustomer() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('customers').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'country': _countryController.text.trim(),
        'agentName': _agentName,
        'createdBy': widget.userId,
        'status': 'lead',
        'timestamp': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer added successfully!')),
      );

      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _addressController.clear();
      _countryController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(_nameController, 'Customer Name'),
            _buildTextField(_emailController, 'Email'),
            _buildTextField(_phoneController, 'Phone Number'),
            _buildTextField(_addressController, 'Address'),
            _buildTextField(_countryController, 'Country'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextFormField(
                initialValue: _agentName,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Agent Name'),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _addCustomer,
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        validator: (value) =>
        value == null || value.trim().isEmpty ? 'Required' : null,
      ),
    );
  }
}
