import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_drawer.dart';

class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard>
    with SingleTickerProviderStateMixin {
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
    for (var section in groupedItems.keys) {
      _expandedSections[section] = false;
    }
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
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('HR Dashboard', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF003087),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
          const Padding(
            padding: EdgeInsets.only(right: 14),
            child: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: Color(0xFF003087)),
            ),
          ),
        ],
      ),
      drawer: const HRDrawer(),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (userName != null && userName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: Text(
                    'Welcome, $userName!',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF003087)),
                  ),
                ),
              ),
            ...groupedItems.entries.map((entry) {
              final sectionTitle = entry.key;
              final items = entry.value;
              final isExpanded = _expandedSections[sectionTitle] ?? false;
              return Column(
                children: [
                  ListTile(
                    tileColor: Colors.white,
                    title: Text(
                      sectionTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003087),
                      ),
                    ),
                    trailing: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: const Color(0xFF003087),
                    ),
                    onTap: () {
                      setState(() {
                        _expandedSections[sectionTitle] = !isExpanded;
                      });
                    },
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: const SizedBox.shrink(),
                    secondChild: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 2.8,
                        ),
                        itemBuilder: (context, index) => _DashboardTile(item: items[index]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, item.route),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(item.icon, color: const Color(0xFF003087)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF003087),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
