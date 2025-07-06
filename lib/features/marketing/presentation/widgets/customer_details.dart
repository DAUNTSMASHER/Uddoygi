import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CustomerDetailsPage extends StatefulWidget {
  final String customerId; // Document ID from Firestore

  const CustomerDetailsPage({super.key, required this.customerId});

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  late DocumentReference customerRef;
  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController addressController;
  late TextEditingController agentNameController;

  bool isEditing = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    customerRef = FirebaseFirestore.instance.collection('customers').doc(widget.customerId);
    _loadCustomerData();
  }

  Future<void> _loadCustomerData() async {
    final doc = await customerRef.get();
    final data = doc.data() as Map<String, dynamic>;

    nameController = TextEditingController(text: data['name']);
    emailController = TextEditingController(text: data['email']);
    phoneController = TextEditingController(text: data['phone']);
    addressController = TextEditingController(text: data['address']);
    agentNameController = TextEditingController(text: data['agentName']);

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _saveChanges() async {
    await customerRef.update({
      'name': nameController.text,
      'email': emailController.text,
      'phone': phoneController.text,
      'address': addressController.text,
      'agentName': agentNameController.text,
    });

    setState(() {
      isEditing = false;
    });
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    agentNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Details'),
        actions: [
          IconButton(
            icon: Icon(isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (isEditing) {
                _saveChanges();
              } else {
                setState(() {
                  isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            _buildTextField('Name', nameController),
            _buildTextField('Email', emailController),
            _buildTextField('Phone', phoneController),
            _buildTextField('Address', addressController),
            _buildTextField('Agent Name', agentNameController),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        readOnly: !isEditing,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
