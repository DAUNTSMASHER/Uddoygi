import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminMonitoringScreen extends StatefulWidget {
  const AdminMonitoringScreen({super.key});

  @override
  State<AdminMonitoringScreen> createState() => _AdminMonitoringScreenState();
}

class _AdminMonitoringScreenState extends State<AdminMonitoringScreen> {
  String _cid = '';

  @override
  void initState() {
    super.initState();
    _loadCid();
  }

  Future<void> _loadCid() async {
    final id = await LocalStorageService.getSavedCompanyId();
    if (mounted) setState(() => _cid = id ?? '');
  }

  @override
  Widget build(BuildContext context) {
    if (_cid.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: UddoygiDesign.surface,
      appBar: AppBar(
        title: Text('Live Floor Monitoring', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 18)),
        backgroundColor: const Color(0xFF1E0040), // _heroPurple
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.support_agent_rounded, color: Colors.redAccent),
            onPressed: () => _showCallSupervisorDialog(),
            tooltip: 'Call Floor Supervisor',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: UddoygiDesign.space20, vertical: UddoygiDesign.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLiveCounter(),
            const SizedBox(height: UddoygiDesign.space32),
            _buildMachineStatusGrid(),
            const SizedBox(height: UddoygiDesign.space32),
            _buildUtilityConsumption(),
            const SizedBox(height: UddoygiDesign.space32),
            _buildOperationalHealth(),
            const SizedBox(height: UddoygiDesign.space32),
            _buildSafetyAlerts(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveCounter() {
    return Container(
      padding: const EdgeInsets.all(UddoygiDesign.space24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E0040), Color(0xFF4C1D95)],
        ),
        borderRadius: BorderRadius.circular(UddoygiDesign.radiusXL),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E0040).withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Today\'s Production',
                style: GoogleFonts.plusJakartaSans(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.15), borderRadius: UddoygiDesign.borderFull),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('LIVE', style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: UddoygiDesign.space20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('1,284', style: GoogleFonts.outfit(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -1)),
              const SizedBox(width: 8),
              Text('/ 1,500', style: GoogleFonts.outfit(color: Colors.white.withOpacity(0.3), fontSize: 24, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: UddoygiDesign.space24),
          ClipRRect(
            borderRadius: BorderRadius.circular(UddoygiDesign.radiusL),
            child: LinearProgressIndicator(
              value: 1284 / 1500,
              backgroundColor: Colors.white.withOpacity(0.08),
              color: Colors.greenAccent,
              minHeight: 10,
            ),
          ),
          const SizedBox(height: UddoygiDesign.space12),
          Text(
            '85.6% of daily goal reached',
            style: GoogleFonts.plusJakartaSans(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildMachineStatusGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Machine Status',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: UddoygiDesign.space16),
        UCard(
          padding: const EdgeInsets.all(UddoygiDesign.space16),
          child: Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final isRunning = index % 3 != 0;
                  final isIdle = index == 3 || index == 9;
                  final color = isRunning ? Colors.green : (isIdle ? Colors.orange : Colors.red);
                  
                  return Container(
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(UddoygiDesign.radiusM),
                      border: Border.all(color: color.withOpacity(0.2), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.precision_manufacturing_rounded, color: color, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          'M-${index + 1}',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: color.withOpacity(0.8)),
                        ),
                      ],
                    ),
                  ).animate(delay: (index * 30).ms).fadeIn().scale(begin: const Offset(0.9, 0.9));
                },
              ),
              const SizedBox(height: UddoygiDesign.space20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _statusLegend(Colors.green, 'Running'),
                  const SizedBox(width: 20),
                  _statusLegend(Colors.orange, 'Idle'),
                  const SizedBox(width: 20),
                  _statusLegend(Colors.red, 'Down'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusLegend(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildUtilityConsumption() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Utility Consumption',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: UddoygiDesign.space16),
        UCard(
          padding: const EdgeInsets.all(UddoygiDesign.space20),
          child: Column(
            children: [
              _utilityRow('Electricity', '420 kW', Icons.bolt_rounded, Colors.amber, 0.7),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
              _utilityRow('Water Usage', '1,200 L', Icons.water_drop_rounded, Colors.blue, 0.4),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
              _utilityRow('Fuel (Generator)', '45 L', Icons.local_gas_station_rounded, Colors.orange, 0.2),
            ],
          ),
        ),
      ],
    );
  }

  Widget _utilityRow(String label, String value, IconData icon, Color color, double pct) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: UddoygiDesign.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: color, fontSize: 15)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(UddoygiDesign.radiusFull),
                child: LinearProgressIndicator(
                  value: pct,
                  backgroundColor: color.withOpacity(0.08),
                  color: color,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyAlerts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Safety Alerts & Logs',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: UddoygiDesign.space16),
        UCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _alertTile('Equipment Overheat', 'Machine M-04 reported temp > 85°C', '2m ago', true),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _alertTile('Floor Maintenance', 'Section B scheduled cleaning', '1h ago', false),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              _alertTile('Safety Protocol', 'Personal protective equipment check', '3h ago', false),
            ],
          ),
        ),
      ],
    );
  }

  Widget _alertTile(String title, String body, String time, bool isCritical) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: UddoygiDesign.space16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (isCritical ? Colors.red : Colors.blue).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isCritical ? Icons.report_problem_rounded : Icons.info_outline_rounded,
          color: isCritical ? Colors.red : Colors.blue,
          size: 20,
        ),
      ),
      title: Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(body, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      trailing: Text(time, style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey[500], fontWeight: FontWeight.w700)),
    );
  }

  void _showCallSupervisorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UddoygiDesign.radiusL)),
        title: Text('Call Floor Supervisor', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text('Notify the supervisor about a critical floor issue?', style: GoogleFonts.plusJakartaSans(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✅ Supervisor notified. Assistance is on the way.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
            ),
            child: Text('Flag Issue & Call', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalHealth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operational Health (Sync)',
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        const SizedBox(height: UddoygiDesign.space16),
        UCard(
          padding: const EdgeInsets.all(UddoygiDesign.space20),
          child: Column(
            children: [
              _healthItem('Supplier Quality', '94% Pass Rate', Icons.verified_user_rounded, Colors.green),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
              _healthItem('R&D Spec Alignment', 'In Sync', Icons.sync_rounded, Colors.blue),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(height: 1, color: Color(0xFFF1F5F9))),
              _healthItem('Actual vs Planned', '-2.4% Variance', Icons.analytics_rounded, Colors.orange),
            ],
          ),
        ),
        const SizedBox(height: UddoygiDesign.space16),
        _buildSupplierAlert(),
      ],
    );
  }

  Widget _healthItem(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(UddoygiDesign.radiusM)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: UddoygiDesign.space16),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, color: Colors.grey[800], fontSize: 14),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 16, color: color),
        ),
      ],
    );
  }

  Widget _buildSupplierAlert() {
    return Container(
      padding: const EdgeInsets.all(UddoygiDesign.space16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(UddoygiDesign.radiusL),
        border: Border.all(color: Colors.red[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: Colors.red, size: 24),
          const SizedBox(width: UddoygiDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Quality Red Flag', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: Colors.red[900])),
                Text(
                  'Raw materials from "Asia Steels" causing 15% wastage spike.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.red[800], fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

}
