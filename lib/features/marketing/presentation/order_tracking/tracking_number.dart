import 'package:flutter/material.dart';

const Color _darkBlue = Color(0xFF0D47A1);

/// TODO: implement your "FedEx Tracking Number" functionality here
class TrackingNumberPage extends StatelessWidget {
  const TrackingNumberPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FedEx Tracking'),
        backgroundColor: _darkBlue,
      ),
      body: const Center(
        child: Text('FedEx tracking number functionality goes here'),
      ),
    );
  }
}
