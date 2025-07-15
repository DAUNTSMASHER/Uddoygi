import 'package:flutter/material.dart';

const Color _darkBlue = Color(0xFF0D47A1);

/// TODO: implement your "Address Validation" functionality here
class AddressValidationPage extends StatelessWidget {
  const AddressValidationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Address Validation'),
        backgroundColor: _darkBlue,
      ),
      body: const Center(
        child: Text('Address validation functionality goes here'),
      ),
    );
  }
}
