import 'package:cloud_firestore/cloud_firestore.dart';

class DataSyncService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 🛒 The Supplier Trigger: When a purchase is logged from a supplier.
  /// - Increase Inventory (Factory)
  /// - Decrease Budget/Track Expense (Admin)
  /// - Create a Payable/Track Loan (HR/Accounts)
  static Future<void> triggerSupplierPurchase({
    required String cid,
    required String supplierId,
    required String materialName,
    required double amount,
    required double quantity,
    required String unit,
  }) async {
    final batch = _firestore.batch();

    // 1. Decrease Budget (Log as Admin Expense)
    final adminExpenseRef = _firestore.collection('companies').doc(cid).collection('expenses').doc();
    batch.set(adminExpenseRef, {
      'title': 'Material Purchase: $materialName',
      'amount': amount,
      'category': 'Procurement',
      'department': 'Operations',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'paid',
      'metadata': {
        'supplierId': supplierId,
        'material': materialName,
        'quantity': '$quantity $unit',
      }
    });

    // 2. Increase Inventory (Factory)
    // Assuming a 'stock' collection or similar
    final stockRef = _firestore.collection('companies').doc(cid).collection('stock').doc(materialName);
    batch.set(stockRef, {
      'itemName': materialName,
      'quantity': FieldValue.increment(quantity),
      'unit': unit,
      'lastUpdated': FieldValue.serverTimestamp(),
      'type': 'raw_material',
    }, SetOptions(merge: true));

    // 3. Create a Payable/Transaction Log
    final payableRef = _firestore.collection('companies').doc(cid).collection('payables').doc();
    batch.set(payableRef, {
      'supplierId': supplierId,
      'amount': amount,
      'dueDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 30))),
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// 🤝 The Order Trigger: When Marketing closes a "Deal".
  /// - It creates a Production Order (Factory).
  /// - It updates Revenue Insights (Admin).
  /// - It notifies RnD if it's a custom-built product.
  static Future<void> triggerOrderClosed({
    required String cid,
    required String customerId,
    required String orderId,
    required double totalValue,
    required List<dynamic> items,
    bool isCustom = false,
  }) async {
    final batch = _firestore.batch();

    // 1. Create Production Order (Factory)
    final workOrderRef = _firestore.collection('companies').doc(cid).collection('workOrders').doc(orderId);
    batch.set(workOrderRef, {
      'orderId': orderId,
      'customerId': customerId,
      'items': items,
      'currentStage': 'Raw Material Prep',
      'status': 'In-Progress',
      'timestamp': FieldValue.serverTimestamp(),
      'priority': 'Medium',
      'cost_impact': totalValue * 0.4, // Estimated production cost
    });

    // 2. Update Revenue Insights (Log Invoice for Admin)
    final invoiceRef = _firestore.collection('companies').doc(cid).collection('invoices').doc(orderId);
    batch.set(invoiceRef, {
      'orderId': orderId,
      'customerId': customerId,
      'grandTotal': totalValue,
      'status': 'unpaid',
      'timestamp': FieldValue.serverTimestamp(),
      'department_id': 'marketing',
    });

    // 3. Notify R&D if custom
    if (isCustom) {
      final notifRef = _firestore.collection('companies').doc(cid).collection('notifications').doc();
      batch.set(notifRef, {
        'title': 'New Custom Order #$orderId',
        'body': 'A custom order has been placed. R&D review required for specifications.',
        'target': 'rnd',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// ⚠️ The Quality Trigger: If the Factory logs a "Failed QC".
  /// - It updates the Supplier's Rank (Supplier Management).
  /// - It flags the Customer Record (Marketing) to warn of a delay.
  static Future<void> triggerQCFailure({
    required String cid,
    required String orderId,
    required String supplierId,
    required String defectType,
    required double lossAmount,
  }) async {
    final batch = _firestore.batch();

    // 1. Update Supplier Rank (Penalty)
    final supplierRef = _firestore.collection('companies').doc(cid).collection('suppliers').doc(supplierId);
    batch.update(supplierRef, {
      'rating': FieldValue.increment(-0.1), // Decrease rating
      'failure_logs': FieldValue.arrayUnion([{
        'orderId': orderId,
        'defect': defectType,
        'loss': lossAmount,
        'timestamp': Timestamp.now(),
      }]),
    });

    // 2. Flag Customer Record / Notify Marketing
    final notifRef = _firestore.collection('companies').doc(cid).collection('notifications').doc();
    batch.set(notifRef, {
      'title': 'Order Delay Risk: #$orderId',
      'body': 'Quality failure detected in production. Customer delivery may be delayed.',
      'target': 'marketing',
      'timestamp': FieldValue.serverTimestamp(),
      'metadata': {
        'orderId': orderId,
        'type': 'qc_failure',
      }
    });

    // Gap D6: Wire to Customer record
    try {
      final woSnap = await _firestore.collection('companies').doc(cid).collection('workOrders').doc(orderId).get();
      if (woSnap.exists) {
        final custId = woSnap.data()?['customerId'];
        if (custId != null) {
          final custRef = _firestore.collection('companies').doc(cid).collection('customers').doc(custId);
          batch.update(custRef, {
            'has_delivery_risk': true,
            'last_risk_order_id': orderId,
            'last_risk_type': defectType,
            'risk_timestamp': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error flagging customer for QC risk: $e');
    }

    await batch.commit();
  }
}
