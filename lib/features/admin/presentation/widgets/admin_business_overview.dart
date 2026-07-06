import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uddoygi/core/utils/finance_utils.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/theme/app_fonts.dart';

const Color _bgDark   = Color(0xFF0F172A);
const Color _bgCard   = Color(0xFF1E293B);
const Color _purple   = Color(0xFF7C3AED);
const Color _green    = Color(0xFF10B981);
const Color _red      = Color(0xFFEF4444);
const Color _amber    = Color(0xFFF59E0B);
const Color _blue     = Color(0xFF3B82F6);
const Color _teal     = Color(0xFF14B8A6);
const Color _pink     = Color(0xFFEC4899);
const Color _orange   = Color(0xFFF97316);
const Color _textMain = Color(0xFFF1F5F9);
const Color _textSub  = Color(0xFF94A3B8);

class AdminBusinessOverview extends StatefulWidget {
  final String cid;
  const AdminBusinessOverview({super.key, required this.cid});

  @override
  State<AdminBusinessOverview> createState() => _AdminBusinessOverviewState();
}

class _AdminBusinessOverviewState extends State<AdminBusinessOverview> {
  bool _loading = true;

  double _totalRevenue = 0;
  int _totalWOs = 0;
  int _pendingWOs = 0;
  int _overdueWOs = 0;
  int _totalEmployees = 0;
  int _presentToday = 0;
  int _pendingLeaves = 0;
  int _totalCustomers = 0;
  int _activeCampaigns = 0;
  double _monthlyExpenses = 0;
  int _openComplaints = 0;
  int _totalComplaints = 0;
  int _activeRD = 0;
  double _payrollCost = 0;
  double _budget = 0;


  double get _profit => _totalRevenue - _monthlyExpenses;
  double get _profitMargin => _totalRevenue > 0 ? (_profit / _totalRevenue) * 100 : 0;

  @override
  void initState() {
    super.initState();
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    if (widget.cid.isEmpty) return;
    setState(() => _loading = true);

    try {
      await Future.wait([
        _fetchInvoices(),
        _fetchWorkOrders(),
        _fetchEmployees(),
        _fetchAttendance(),
        _fetchLeaves(),
        _fetchCustomers(),
        _fetchCampaigns(),
        _fetchExpenses(),
        _fetchPayroll(),
        _fetchComplaints(),
        _fetchRD(),
        _fetchBudget(),
      ]);
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchInvoices() async {
    final snap = await DB.colSync(widget.cid, C.invoices).get();
    double rev = 0;
    for (final doc in snap.docs) {
      final d = doc.data();
      rev += (d['grandTotal'] is num ? (d['grandTotal'] as num).toDouble() : 0);
    }
    if (mounted) {
      setState(() {
        _totalRevenue = FinanceUtils.round(rev);
      });
    }
  }

  Future<void> _fetchWorkOrders() async {
    final snap = await DB.colSync(widget.cid, C.workOrders).get();
    int pending = 0, overdue = 0;
    final now = DateTime.now();
    for (final doc in snap.docs) {
      final d = doc.data();
      final status = (d['status'] ?? '').toString();
      if (status != 'Completed' && status != 'Delivered') {
        pending++;
        final deadline = d['finalDate'] as Timestamp?;
        if (deadline != null && deadline.toDate().isBefore(now)) overdue++;
      }
    }
    if (mounted) {
      setState(() {
        _totalWOs = snap.docs.length;
        _pendingWOs = pending;
        _overdueWOs = overdue;
      });
    }
  }

  Future<void> _fetchEmployees() async {
    final snap = await DB.colSync(widget.cid, C.employees).get();
    if (mounted) setState(() => _totalEmployees = snap.docs.length);
  }

  Future<void> _fetchAttendance() async {
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final snap = await DB.colSync(widget.cid, C.attendance)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .where('date', isLessThan: Timestamp.fromDate(todayEnd))
        .get();
    int present = 0;
    for (final doc in snap.docs) {
      if ((doc.data()['status'] ?? '').toString().toLowerCase() == 'present') present++;
    }
    if (mounted) setState(() => _presentToday = present);
  }

  Future<void> _fetchLeaves() async {
    final snap = await DB.colSync(widget.cid, C.leaveRequests)
        .where('status', isEqualTo: 'pending').get();
    if (mounted) setState(() => _pendingLeaves = snap.docs.length);
  }

  Future<void> _fetchCustomers() async {
    final snap = await DB.colSync(widget.cid, C.customers).get();
    if (mounted) setState(() => _totalCustomers = snap.docs.length);
  }

  Future<void> _fetchCampaigns() async {
    final snap = await DB.colSync(widget.cid, C.campaigns)
        .where('status', isEqualTo: 'active').get();
    if (mounted) setState(() => _activeCampaigns = snap.docs.length);
  }

  Future<void> _fetchExpenses() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final snap = await DB.colSync(widget.cid, C.expenses)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
        .get();
    double total = 0;
    for (final doc in snap.docs) {
      total += ((doc.data()['amount'] ?? 0) as num).toDouble();
    }
    if (mounted) setState(() => _monthlyExpenses = FinanceUtils.round(total));
  }

  Future<void> _fetchPayroll() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final snap = await DB.colSync(widget.cid, C.salaries)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(monthEnd))
        .get();
    double total = 0;
    for (final doc in snap.docs) {
      total += ((doc.data()['amount'] ?? doc.data()['netPay'] ?? doc.data()['salary'] ?? 0) as num).toDouble();
    }
    if (mounted) setState(() => _payrollCost = FinanceUtils.round(total));
  }

  Future<void> _fetchComplaints() async {
    final snap = await DB.colSync(widget.cid, C.complaints).get();
    int open = 0;
    for (final doc in snap.docs) {
      if ((doc.data()['status'] ?? '').toString().toLowerCase() == 'pending') open++;
    }
    if (mounted) setState(() { _totalComplaints = snap.docs.length; _openComplaints = open; });
  }

  Future<void> _fetchRD() async {
    try {
      final snap = await DB.colSync(widget.cid, C.rndProjects).get();
      int active = 0;
      for (final doc in snap.docs) {
        if ((doc.data()['status'] ?? '').toString().toLowerCase() == 'active') active++;
      }
      if (mounted) setState(() => _activeRD = active);
    } catch (_) {}
  }

  Future<void> _fetchBudget() async {
    try {
      final snap = await DB.colSync(widget.cid, C.budget).limit(1).get();
      if (snap.docs.isNotEmpty) {
        final b = (snap.docs.first.data()['amount'] ?? 0) as num;
        if (mounted) setState(() => _budget = b.toDouble());
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(color: _purple)),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _bgDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: _purple.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 24),
          _executiveKpiRow(),
          const SizedBox(height: 24),
          _sectorHealthGrid(),
          const SizedBox(height: 24),
          _alertsSection(),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BUSINESS COMMAND CENTER', style: AppFonts.banglaHeading(color: _purple, fontSize: 12, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Enterprise Overview', style: AppFonts.banglaHeading(color: _textMain, fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _profitMargin >= 15 ? _green.withValues(alpha: 0.15) : _profitMargin >= 5 ? _amber.withValues(alpha: 0.15) : _red.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _profitMargin >= 15 ? _green.withValues(alpha: 0.4) : _profitMargin >= 5 ? _amber.withValues(alpha: 0.4) : _red.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.trending_up_rounded, size: 14, color: _profitMargin >= 15 ? _green : _profitMargin >= 5 ? _amber : _red),
              const SizedBox(width: 6),
              Text('${_profitMargin.toStringAsFixed(1)}% Margin', style: AppFonts.banglaData(color: _textMain, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _executiveKpiRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final children = [
          _KpiTile(label: 'Total Revenue', value: '৳${_fmtLarge(_totalRevenue)}', icon: Icons.account_balance_rounded, color: _green, bgColor: _green.withValues(alpha: 0.1)),
          _KpiTile(label: 'Net Profit', value: '৳${_fmtLarge(_profit)}', icon: Icons.trending_up_rounded, color: _profit >= 0 ? _teal : _red, bgColor: _profit >= 0 ? _teal.withValues(alpha: 0.1) : _red.withValues(alpha: 0.1)),
          _KpiTile(label: 'Active Orders', value: '${_pendingWOs}', icon: Icons.precision_manufacturing_rounded, color: _blue, bgColor: _blue.withValues(alpha: 0.1)),
          _KpiTile(label: 'Employees', value: '${_totalEmployees}', icon: Icons.people_rounded, color: _purple, bgColor: _purple.withValues(alpha: 0.1)),
          _KpiTile(label: 'Present Today', value: '${_presentToday}', icon: Icons.fact_check_rounded, color: _amber, bgColor: _amber.withValues(alpha: 0.1)),
          _KpiTile(label: 'Overdue Orders', value: '${_overdueWOs}', icon: Icons.warning_rounded, color: _overdueWOs > 0 ? _red : _green, bgColor: _overdueWOs > 0 ? _red.withValues(alpha: 0.1) : _green.withValues(alpha: 0.1)),
        ];
        if (isWide) {
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: children.map((e) => SizedBox(width: (constraints.maxWidth - 50) / 6, child: e)).toList(),
          );
        }
        return Column(
          children: [
            Row(children: [Expanded(child: children[0]), const SizedBox(width: 10), Expanded(child: children[1]), const SizedBox(width: 10), Expanded(child: children[2])]),
            const SizedBox(height: 10),
            Row(children: [Expanded(child: children[3]), const SizedBox(width: 10), Expanded(child: children[4]), const SizedBox(width: 10), Expanded(child: children[5])]),
          ],
        );
      },
    );
  }

  Widget _sectorHealthGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SECTOR HEALTH', style: AppFonts.banglaHeading(color: _textSub, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            final crossAxisCount = isWide ? 3 : 2;
            final cards = [
              _SectorCard(
                name: 'Manufacturing',
                icon: Icons.precision_manufacturing_rounded,
                color: _blue,
                metrics: ['${_totalWOs} Total Orders', '${_pendingWOs} Active', '${_overdueWOs} Overdue'],
                status: _overdueWOs > 2 ? _red : _overdueWOs > 0 ? _amber : _green,
              ),
              _SectorCard(
                name: 'Sales & Marketing',
                icon: Icons.trending_up_rounded,
                color: _green,
                metrics: ['${_totalCustomers} Customers', '${_activeCampaigns} Campaigns', '৳${_fmtLarge(_totalRevenue)} Revenue'],
                status: _totalRevenue > 0 ? _green : _amber,
              ),
              _SectorCard(
                name: 'Human Resources',
                icon: Icons.people_rounded,
                color: _purple,
                metrics: ['${_totalEmployees} Employees', '${_presentToday} Present', '${_pendingLeaves} Leave Reqs'],
                status: _pendingLeaves > 10 ? _amber : _green,
              ),
              _SectorCard(
                name: 'Finance',
                icon: Icons.account_balance_wallet_rounded,
                color: _teal,
                metrics: ['৳${_fmtLarge(_monthlyExpenses)} Expenses', '৳${_fmtLarge(_payrollCost)} Payroll', 'Budget: ${_budget > 0 ? '${(_monthlyExpenses / _budget * 100).round()}%' : 'N/A'}'],
                status: _monthlyExpenses > _budget && _budget > 0 ? _red : _green,
              ),
              _SectorCard(
                name: 'R&D',
                icon: Icons.science_rounded,
                color: _pink,
                metrics: ['${_activeRD} Active Projects'],
                status: _activeRD > 0 ? _green : _amber,
              ),
              _SectorCard(
                name: 'Customer Support',
                icon: Icons.headset_mic_rounded,
                color: _orange,
                metrics: ['${_openComplaints} Open', '${_totalComplaints} Total'],
                status: _openComplaints > 5 ? _red : _openComplaints > 0 ? _amber : _green,
              ),
            ];
            return _GridLayout(crossAxisCount: crossAxisCount, spacing: 10, children: cards);
          },
        ),
      ],
    );
  }

  Widget _alertsSection() {
    final alerts = <_AlertItem>[];

    if (_overdueWOs > 0) alerts.add(_AlertItem(icon: Icons.warning_rounded, color: _red, text: '$_overdueWOs overdue work orders need immediate attention'));
    if (_pendingLeaves > 0) alerts.add(_AlertItem(icon: Icons.event_busy_rounded, color: _amber, text: '$_pendingLeaves pending leave requests awaiting approval'));
    if (_openComplaints > 3) alerts.add(_AlertItem(icon: Icons.report_problem_rounded, color: _red, text: '$_openComplaints open complaints require resolution'));
    if (_totalEmployees > 0 && _presentToday < _totalEmployees * 0.5) alerts.add(_AlertItem(icon: Icons.people_outline_rounded, color: _amber, text: 'Low attendance today: only $_presentToday of $_totalEmployees present'));

    if (alerts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ALERTS & ACTION ITEMS', style: AppFonts.banglaHeading(color: _red, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
        const SizedBox(height: 12),
        ...alerts.map((a) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: a.color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: a.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(a.icon, size: 18, color: a.color),
              const SizedBox(width: 12),
              Expanded(child: Text(a.text, style: AppFonts.banglaBody(color: _textMain, fontSize: 13, fontWeight: FontWeight.w500))),
            ],
          ),
        )),
      ],
    );
  }

  String _fmtLarge(double n) {
    if (n >= 10000000) return '${(n / 10000000).toStringAsFixed(1)}Cr';
    if (n >= 100000) return '${(n / 100000).toStringAsFixed(1)}L';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toStringAsFixed(0);
  }
}

class _KpiTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color, bgColor;
  const _KpiTile({required this.label, required this.value, required this.icon, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: AppFonts.banglaBody(color: _textSub, fontSize: 10, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: AppFonts.banglaData(color: _textMain, fontSize: 18, fontWeight: FontWeight.w800, height: 1.1)),
        ],
      ),
    );
  }
}

class _SectorCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color, status;
  final List<String> metrics;
  const _SectorCard({required this.name, required this.icon, required this.color, required this.metrics, required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: status.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(name, style: AppFonts.banglaHeading(color: _textMain, fontSize: 13, fontWeight: FontWeight.w700))),
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: status, shape: BoxShape.circle, boxShadow: [BoxShadow(color: status.withValues(alpha: 0.4), blurRadius: 6)]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...metrics.map((m) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Container(width: 4, height: 4, decoration: BoxDecoration(color: _textSub, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(m, style: AppFonts.banglaBody(color: _textSub, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _AlertItem {
  final IconData icon;
  final Color color;
  final String text;
  const _AlertItem({required this.icon, required this.color, required this.text});
}

class _GridLayout extends StatelessWidget {
  final int crossAxisCount;
  final double spacing;
  final List<Widget> children;
  const _GridLayout({required this.crossAxisCount, required this.spacing, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (int i = 0; i < children.length; i += crossAxisCount) {
      final rowChildren = <Widget>[];
      for (int j = 0; j < crossAxisCount && i + j < children.length; j++) {
        rowChildren.add(Expanded(child: children[i + j]));
        if (j < crossAxisCount - 1 && i + j + 1 < children.length) rowChildren.add(SizedBox(width: spacing));
      }
      rows.add(Row(children: rowChildren));
      rows.add(SizedBox(height: spacing));
    }
    return Column(children: rows);
  }
}
