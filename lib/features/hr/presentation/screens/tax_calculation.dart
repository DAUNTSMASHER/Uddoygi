import 'package:flutter/material.dart';

class TaxCalculationPage extends StatelessWidget {
  const TaxCalculationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B3552), // Dark Blue
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B3552),
        title: const Text(
          'Tax Calculation - BD',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        padding: const EdgeInsets.all(16),
        child: Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 6,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Income Breakdown',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0B3552)),
                ),
                const SizedBox(height: 10),
                buildRow('Basic Salary:', '৳ 6,00,000'),
                buildRow('House Rent Allowance:', '৳ 2,00,000'),
                buildRow('Medical Allowance:', '৳ 1,00,000'),
                buildRow('Conveyance:', '৳ 50,000'),
                const Divider(height: 30, thickness: 1.2),
                buildRow('Total Income:', '৳ 9,50,000'),

                const SizedBox(height: 20),
                const Text(
                  'Exemptions & Deductions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0B3552)),
                ),
                const SizedBox(height: 10),
                buildRow('House Rent Exempted:', '৳ 1,50,000'),
                buildRow('Medical Exempted:', '৳ 1,20,000'),
                const Divider(height: 30, thickness: 1.2),
                buildRow('Net Taxable Income:', '৳ 6,80,000'),

                const SizedBox(height: 20),
                const Text(
                  'Tax Calculation (FY 2024-25)',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0B3552)),
                ),
                const SizedBox(height: 10),
                buildRow('0 – 3,50,000 (0%)', '৳ 0'),
                buildRow('Next 1,00,000 (5%)', '৳ 5,000'),
                buildRow('Next 3,00,000 (10%)', '৳ 30,000'),
                buildRow('Remaining 30,000 (15%)', '৳ 4,500'),
                const Divider(height: 30, thickness: 1.5),
                buildRow('💰 Total Tax Payable:', '৳ 39,500', isTotal: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.green.shade700 : Colors.grey[800],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 18 : 16,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.green.shade700 : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
}
