import 'package:flutter/material.dart';

const Color _darkBlue = Color(0xFF0D47A1);

/// TODO: implement your "Shipping Agents Directory" functionality here
class ShippingAgentDirectoryPage extends StatelessWidget {
  const ShippingAgentDirectoryPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shipping Agents'),
        backgroundColor: _darkBlue,
      ),
      body: const Center(
        child: Text('Shipping agents directory functionality goes here'),
      ),
    );
  }
}
