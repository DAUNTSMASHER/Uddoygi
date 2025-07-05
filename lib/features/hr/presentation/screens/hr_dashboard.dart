import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_drawer.dart';

class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  String? userName;
  final ScrollController _scrollController = ScrollController();
  final Map<String, bool> _expandedSections = {};

  final Map<String, List<_DashboardItem>> groupedItems = {
    'Employee': [
      _DashboardItem('Directory', Icons.people, '/hr/employee_directory'),
      _DashboardItem('Shifts', Icons.schedule, '/hr/shift_tracker'),
      _DashboardItem('Recruitment', Icons.how_to_reg, '/hr/recruitment'),
    ],
    'Attendance': [
      _DashboardItem('Attendance', Icons.event_available, '/hr/attendance'),
      _DashboardItem('Leave', Icons.beach_access, '/hr/leave_management'),
    ],
    'Payroll': [
      _DashboardItem('Processing', Icons.attach_money, '/hr/payroll_processing'),
      _DashboardItem('Payslips', Icons.receipt_long, '/hr/payslip'),
      _DashboardItem('Salaries', Icons.money, '/hr/salary_management'),
    ],
    'Benefits': [
      _DashboardItem('Compensation', Icons.card_giftcard, '/hr/benefits_compensation'),
      _DashboardItem('Loans', Icons.account_balance, '/hr/loan_approval'),
      _DashboardItem('Incentives', Icons.emoji_events, '/hr/incentives'),
    ],
    'Finance': [
      _DashboardItem('Ledger', Icons.book, '/hr/general_ledger'),
      _DashboardItem('Payables', Icons.outbox, '/hr/accounts_payable'),
      _DashboardItem('Receivables', Icons.inbox, '/hr/accounts_receivable'),
      _DashboardItem('Balance', Icons.account_balance_wallet, '/hr/balance_update'),
      _DashboardItem('Tax', Icons.calculate, '/hr/tax'),
    ],
    'Procurement': [
      _DashboardItem('Management', Icons.shopping_cart, '/hr/procurement'),
      _DashboardItem('Budget', Icons.trending_up, '/hr/budget_forecast'),
    ],
    'Communication': [
      _DashboardItem('Notices', Icons.notifications, '/hr/notices'),
      _DashboardItem('Messages', Icons.message, '/common/messages'),
    ],
    'Support': [
      _DashboardItem('Complaints', Icons.support_agent, '/common/complaints'),
    ]
  };

  @override
  void initState() {
    super.initState();
    _loadSession();
    groupedItems.keys.forEach((section) {
      _expandedSections[section] = true;
    });
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    setState(() {
      userName = (session?['name'] ?? session?['email']) ?? '';
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    await LocalStorageService.clearSession();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        title: const Text('HR Dashboard'),
        backgroundColor: const Color(0xFF003087), // PayPal deep blue
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: const Icon(Icons.person, color: Color(0xFF003087)),
            ),
          ),
        ],
      ),
      drawer: const HRDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userName != null && userName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Welcome, $userName',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF003087)),
                ),
              ),
            ...groupedItems.entries.map((entry) {
              final sectionTitle = entry.key;
              final items = entry.value;
              final isExpanded = _expandedSections[sectionTitle] ?? true;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      sectionTitle,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF003087)),
                    ),
                    trailing: Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey[700],
                    ),
                    onTap: () {
                      setState(() {
                        _expandedSections[sectionTitle] = !isExpanded;
                      });
                    },
                  ),
                  AnimatedCrossFade(
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 2.6,
                        ),
                        itemBuilder: (context, index) => _DashboardTile(item: items[index]),
                      ),
                    ),
                    crossFadeState:
                    isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                  ),
                  const SizedBox(height: 18),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final String route;
  const _DashboardItem(this.title, this.icon, this.route);
}

class _DashboardTile extends StatelessWidget {
  final _DashboardItem item;
  const _DashboardTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, item.route),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: 22, color: const Color(0xFF003087)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF003087)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
