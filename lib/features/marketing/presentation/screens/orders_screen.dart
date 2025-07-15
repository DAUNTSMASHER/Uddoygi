// lib/features/marketing/presentation/screens/orders_screen.dart

import 'package:flutter/material.dart';

// point these at your real files under presentation/order_tracking
import '../order_tracking/factory_tracking.dart';
import '../order_tracking/address_validation.dart';
import '../order_tracking/tracking_number.dart';
import '../order_tracking/shipping_agent_directory.dart';

const Color _darkBlue = Color(0xFF0D47A1);

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final sections = <_SectionItem>[
      _SectionItem(
        label: 'Factory Tracker',
        icon: Icons.factory,
        page: const FactoryTrackingPage(),
      ),
      _SectionItem(
        label: 'Address Validation',
        icon: Icons.location_on,
        page: const AddressValidationPage(),
      ),
      _SectionItem(
        label: 'FedEx Tracking',
        icon: Icons.local_shipping,
        page: const TrackingNumberPage(),
      ),
      _SectionItem(
        label: 'Shipping Agents',
        icon: Icons.person_pin_circle,
        page: const ShippingAgentDirectoryPage(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Work‑Orders'),
        backgroundColor: _darkBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            for (final section in sections)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => section.page)),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 4,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(section.icon, size: 48, color: _darkBlue),
                        const SizedBox(height: 12),
                        Text(
                          section.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
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
}

class _SectionItem {
  final String label;
  final IconData icon;
  final Widget page;

  const _SectionItem({
    required this.label,
    required this.icon,
    required this.page,
  });
}
