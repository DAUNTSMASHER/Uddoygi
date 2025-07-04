import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:uddoygi/features/hr/presentation/widgets/hr_drawer.dart';

class HRDashboard extends StatefulWidget {
  const HRDashboard({super.key});

  @override
  State<HRDashboard> createState() => _HRDashboardState();
}

class _HRDashboardState extends State<HRDashboard> {
  String? userName;
  String? lastSection;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _sectionKeys = {};

  final Map<String, List<_DashboardItem>> groupedItems = {
    '👨‍💼 Employee': [
      _DashboardItem('Employee Directory', Icons.people, Colors.indigo, '/hr/employee_directory'),
      _DashboardItem('Shift Tracker', Icons.schedule, Colors.teal, '/hr/shift_tracker'),
      _DashboardItem('Recruitment', Icons.how_to_reg, Colors.deepPurple, '/hr/recruitment'),
    ],
    '🕒 Attendance & Leave': [
      _DashboardItem('Attendance', Icons.event_available, Colors.blue, '/hr/attendance'),
      _DashboardItem('Leave Management', Icons.beach_access, Colors.orange, '/hr/leave_management'),
    ],
    '💰 Payroll': [
      _DashboardItem('Payroll Processing', Icons.attach_money, Colors.green, '/hr/payroll_processing'),
      _DashboardItem('Payslips', Icons.receipt_long, Colors.blueGrey, '/hr/payslip'),
      _DashboardItem('Salary Management', Icons.money, Colors.amber, '/hr/salary_management'),
    ],
    '🎁 Benefits & Loans': [
      _DashboardItem('Benefits & Compensation', Icons.card_giftcard, Colors.deepOrange, '/hr/benefits_compensation'),
      _DashboardItem('Loan Approval', Icons.account_balance, Colors.brown, '/hr/loan_approval'),
      _DashboardItem('Incentives', Icons.emoji_events, Colors.pink, '/hr/incentives'),
    ],
    '📊 Accounting & Tax': [
      _DashboardItem('General Ledger', Icons.book, Colors.cyan, '/hr/general_ledger'),
      _DashboardItem('Accounts Payable', Icons.outbox, Colors.red, '/hr/accounts_payable'),
      _DashboardItem('Accounts Receivable', Icons.inbox, Colors.green, '/hr/accounts_receivable'),
      _DashboardItem('Balance Update', Icons.account_balance_wallet, Colors.teal, '/hr/balance_update'),
      _DashboardItem('Tax Management', Icons.calculate, Colors.indigoAccent, '/hr/tax'),
    ],
    '🛒 Procurement': [
      _DashboardItem('Procurement Management', Icons.shopping_cart, Colors.orangeAccent, '/hr/procurement'),
      _DashboardItem('Budget Forecast', Icons.trending_up, Colors.deepPurpleAccent, '/hr/budget_forecast'),
    ],
    '📨 Communication': [
      _DashboardItem('Notices', Icons.notifications, Colors.purple, '/hr/notices'),
      _DashboardItem('Messages', Icons.message, Colors.blueGrey, '/common/messages'),
    ],
    '🛠 Support': [
      _DashboardItem('Complaints', Icons.support_agent, Colors.deepOrangeAccent, '/common/complaints'),
    ]
  };

  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadLastSection();
  }

  Future<void> _loadSession() async {
    final session = await LocalStorageService.getSession();
    setState(() {
      userName = (session?['name'] ?? session?['email']) ?? '';
    });
  }

  Future<void> _loadLastSection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSection = prefs.getString('lastTappedSection');

    if (savedSection != null && _sectionKeys.containsKey(savedSection)) {
      // Wait for the widgets to build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = _sectionKeys[savedSection]!.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(context,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              alignment: 0.1);
        }
      });
    }
  }

  Future<void> _saveLastSection(String section) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastTappedSection', section);
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
    for (var key in groupedItems.keys) {
      _sectionKeys[key] = GlobalKey();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HR Dashboard'),
        backgroundColor: Colors.indigo,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: CircleAvatar(
              backgroundColor: Colors.indigo[100],
              child: const Icon(Icons.person, color: Colors.indigo),
            ),
          ),
        ],
      ),
      drawer: const HRDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          controller: _scrollController,
          children: [
            if (userName != null && userName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  'Welcome, $userName',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16, color: Colors.indigo),
                ),
              ),
            const Text("📂 Advanced Sections", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...groupedItems.entries.map((entry) {
              final title = entry.key;
              final items = entry.value;

              return Column(
                key: _sectionKeys[title],
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () async {
                      await _saveLastSection(title);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Remembered section: $title'),
                        duration: const Duration(seconds: 1),
                      ));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  ...items.map((item) => _DashboardTile(item: item)),
                  const SizedBox(height: 20),
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
  final Color color;
  final String route;

  const _DashboardItem(this.title, this.icon, this.color, this.route);
}

class _DashboardTile extends StatelessWidget {
  final _DashboardItem item;
  const _DashboardTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.pushNamed(context, item.route),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: item.color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: item.color),
        ),
        child: Row(
          children: [
            Icon(item.icon, size: 28, color: item.color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: item.color),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
