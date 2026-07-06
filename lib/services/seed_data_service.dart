import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uddoygi/services/db.dart';

class SeedDataService {
  static final _products = [
    {'model_name': 'Premium Brazilian Curly 14"', 'unit_price': 85, 'production_cost': 35, 'production_time': '3 days', 'colour': 'Dark Brown', 'curl': '3B', 'size': '14"', 'density': '150%', 'gender': 'Female', 'stock': 50},
    {'model_name': 'Premium Brazilian Curly 16"', 'unit_price': 110, 'production_cost': 45, 'production_time': '3 days', 'colour': 'Dark Brown', 'curl': '3B', 'size': '16"', 'density': '150%', 'gender': 'Female', 'stock': 40},
    {'model_name': 'Natural Straight 14"', 'unit_price': 65, 'production_cost': 28, 'production_time': '2 days', 'colour': 'Black', 'curl': '1A', 'size': '14"', 'density': '130%', 'gender': 'Female', 'stock': 60},
    {'model_name': 'Body Wave 16"', 'unit_price': 95, 'production_cost': 40, 'production_time': '3 days', 'colour': 'Dark Brown', 'curl': '2A', 'size': '16"', 'density': '140%', 'gender': 'Female', 'stock': 35},
    {'model_name': 'Deep Wave 14"', 'unit_price': 80, 'production_cost': 38, 'production_time': '3 days', 'colour': 'Black', 'curl': '3C', 'size': '14"', 'density': '150%', 'gender': 'Female', 'stock': 25},
  ];

  static final _customers = [
    {'name': 'Fatima Begum', 'email': 'fatima@example.com', 'phone': '+8801711000001', 'country': 'Bangladesh', 'city': 'Dhaka', 'status': 'confirmed'},
    {'name': 'Sarah Johnson', 'email': 'sarah@example.com', 'phone': '+12025550001', 'country': 'USA', 'city': 'New York', 'status': 'confirmed'},
    {'name': 'Aisha Mohammed', 'email': 'aisha@example.com', 'phone': '+971501234567', 'country': 'UAE', 'city': 'Dubai', 'status': 'confirmed'},
  ];

  static final _stocks = [
    {'name': 'Raw Hair — Brazilian', 'sku': 'RAW-BR-001', 'qty': 500, 'unit': 'kg', 'minThreshold': 100, 'maxThreshold': 1000, 'category': 'Raw Material'},
    {'name': 'Synthetic Fiber — Premium', 'sku': 'SYN-PR-001', 'qty': 200, 'unit': 'kg', 'minThreshold': 50, 'maxThreshold': 500, 'category': 'Raw Material'},
    {'name': 'Weaving Net — Black', 'sku': 'NET-BK-001', 'qty': 1000, 'unit': 'pcs', 'minThreshold': 200, 'maxThreshold': 3000, 'category': 'Accessories'},
    {'name': 'Dye — Dark Brown', 'sku': 'DYE-DB-001', 'qty': 50, 'unit': 'L', 'minThreshold': 10, 'maxThreshold': 100, 'category': 'Chemicals'},
    {'name': 'Packaging Box — Medium', 'sku': 'PKG-MD-001', 'qty': 300, 'unit': 'pcs', 'minThreshold': 50, 'maxThreshold': 600, 'category': 'Packaging'},
  ];

  static final _expenses = [
    {'vendor': 'Hair World Ltd.', 'category': 'Raw Material', 'amount': 250000, 'paidAmount': 200000, 'dueDate': '2026-02-15', 'status': 'partial', 'costCenter': 'factory', 'notes': 'Raw hair batch'},
    {'vendor': 'BD Power Supply', 'category': 'Utilities', 'amount': 45000, 'paidAmount': 45000, 'dueDate': '2026-02-28', 'status': 'paid', 'costCenter': 'factory', 'notes': 'Electricity bill'},
    {'vendor': 'Digital Marketing Pro', 'category': 'Marketing', 'amount': 75000, 'paidAmount': 50000, 'dueDate': '2026-03-01', 'status': 'partial', 'costCenter': 'marketing', 'notes': 'Social media campaign'},
    {'vendor': 'Staff Welfare Fund', 'category': 'HR & Welfare', 'amount': 20000, 'paidAmount': 20000, 'dueDate': '2026-02-05', 'status': 'paid', 'costCenter': 'hr', 'notes': 'Staff lunch'},
  ];

  static final _tasks = [
    {'title': 'Approve Q1 Marketing Budget', 'description': 'Review budget for Q1 campaigns', 'assignerName': 'Md. Rafiq Hasan', 'assigneeName': 'Farzana Chowdhury', 'dueDate': '2026-02-20', 'priority': 'high', 'status': 'pending'},
    {'title': 'Complete Production of Order INV-001', 'description': 'Weaving and quality check', 'assignerName': 'Karim Uddin', 'assigneeName': 'Jahangir Alam', 'dueDate': '2026-02-18', 'priority': 'high', 'status': 'in_progress'},
    {'title': 'Hire 2 New Machine Operators', 'description': 'Interview and onboard operators', 'assignerName': 'Shamima Akhter', 'assigneeName': 'Nusrat Jahan', 'dueDate': '2026-02-28', 'priority': 'medium', 'status': 'pending'},
  ];

  static bool _seeded = false;

  static Future<void> seedIfEmpty(String cid) async {
    if (_seeded || cid.isEmpty) return;

    final count = await DB.colSync(cid, C.products).limit(1).get();
    if (count.docs.isNotEmpty && count.docs.first.id != '_init') return;

    _seeded = true;
    final now = DateTime.now();
    final root = FirebaseFirestore.instance.collection('data').doc(cid);

    final batch = FirebaseFirestore.instance.batch();
    int ops = 0;

    for (final p in _products) {
      batch.set(root.collection('products').doc(), {
        ...p,
        'companyId': cid,
        'archived': false,
        'createdBy': 'seed@uddoygi.com',
        'createdAt': now,
      });
      ops++;
    }

    for (final c in _customers) {
      batch.set(root.collection('customers').doc(), {
        ...c,
        'companyId': cid,
        'agentEmail': 'farzana@uddoygi.com',
        'agentName': 'Farzana Chowdhury',
        'createdBy': 'seed@uddoygi.com',
        'timestamp': now,
        'updatedAt': now,
      });
      ops++;
    }

    for (final s in _stocks) {
      batch.set(root.collection('stocks').doc(), {
        ...s,
        'companyId': cid,
        'lastUpdated': now,
      });
      ops++;
    }

    for (final e in _expenses) {
      batch.set(root.collection('expenses').doc(), {
        ...e,
        'companyId': cid,
        'balance': (e['amount'] as int) - (e['paidAmount'] as int),
        'currency': 'BDT',
        'attachments': [],
        'createdAt': now,
      });
      ops++;
    }

    for (final t in _tasks) {
      batch.set(root.collection('tasks').doc(), {
        ...t,
        'companyId': cid,
        'createdAt': now,
        'updatedAt': now,
      });
      ops++;
    }

    if (ops > 0) await batch.commit();
  }
}
