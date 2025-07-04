import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MarketingDrawer extends StatelessWidget {
  const MarketingDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: Colors.white,
                ),
                SizedBox(height: 8),
                Text(
                  'Marketing Panel',
                  style: TextStyle(
                    fontSize: 20,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          _buildTile(
            context,
            'Dashboard',
            Icons.dashboard_outlined,
            '/marketing/dashboard',
          ),
          _buildTile(
            context,
            'Clients',
            Icons.people_alt_outlined,
            '/marketing/clients',
          ),
          _buildTile(
            context,
            'Sales & Invoices',
            Icons.receipt_long_outlined,
            '/marketing/sales',
          ),
          _buildTile(
            context,
            'Task Assignment',
            Icons.task_outlined,
            '/marketing/task_assignment',
          ),
          _buildTile(
            context,
            'Campaigns',
            Icons.campaign_outlined,
            '/marketing/campaign',
          ),
          _buildTile(
            context,
            'Orders',
            Icons.shopping_bag_outlined,
            '/marketing/orders',
          ),
          _buildTile(
            context,
            'Loan Requests',
            Icons.request_page_outlined,
            '/marketing/loan_request',
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
    );
  }

  ListTile _buildTile(
    BuildContext context,
    String title,
    IconData icon,
    String route,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.indigo),
      title: Text(title),
      onTap: () => Navigator.pushReplacementNamed(context, route),
    );
  }
}
