// lib/features/payments/domain/models/employee_payment_method_model.dart
//
// Represents a single payment receive method registered by an employee.
//
// Firestore path (preferred):
//   data/{companyId}/users/{employeeUid}/payment_methods/{methodId}
//
// Fields are also mirrored to the parent users doc for quick HR reads:
//   data/{companyId}/users/{employeeUid}
//     defaultPaymentMethodId: String
//     paymentMethod:          String  (label of default method)
//     paymentAccount:         String  (account number of default)
//     paymentName:            String  (account holder name of default)
//     paymentVerified:        bool
// ─────────────────────────────────────────────────────────────────────────────
import 'package:cloud_firestore/cloud_firestore.dart';

// ── Payment method types ──────────────────────────────────────────────────────
enum EmpPayMethodType { bkash, nagad, rocket, upay, bank, cash, other }

extension EmpPayMethodTypeX on EmpPayMethodType {
  String get label => switch (this) {
        EmpPayMethodType.bkash  => 'bKash',
        EmpPayMethodType.nagad  => 'Nagad',
        EmpPayMethodType.rocket => 'Rocket',
        EmpPayMethodType.upay   => 'Upay',
        EmpPayMethodType.bank   => 'Bank Transfer',
        EmpPayMethodType.cash   => 'Cash',
        EmpPayMethodType.other  => 'Other',
      };

  static EmpPayMethodType fromString(String? s) => switch (s?.toLowerCase()) {
        'bkash'         => EmpPayMethodType.bkash,
        'nagad'         => EmpPayMethodType.nagad,
        'rocket'        => EmpPayMethodType.rocket,
        'upay'          => EmpPayMethodType.upay,
        'bank transfer' => EmpPayMethodType.bank,
        'bank'          => EmpPayMethodType.bank,
        'cash'          => EmpPayMethodType.cash,
        _               => EmpPayMethodType.other,
      };
}

// ── Model ─────────────────────────────────────────────────────────────────────
class EmployeePaymentMethod {
  final String            id;
  final EmpPayMethodType  type;
  final String            accountNumber;   // wallet number or bank account
  final String            accountName;     // account holder name
  final String            bankName;        // only for bank transfer
  final String            branchName;      // only for bank transfer
  final String            routingNumber;   // only for bank transfer
  final bool              isDefault;
  final bool              isVerifiedByHr;
  final DateTime?         createdAt;
  final DateTime?         updatedAt;

  const EmployeePaymentMethod({
    required this.id,
    required this.type,
    required this.accountNumber,
    required this.accountName,
    this.bankName       = '',
    this.branchName     = '',
    this.routingNumber  = '',
    this.isDefault      = false,
    this.isVerifiedByHr = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isBank => type == EmpPayMethodType.bank;

  // ── Masked account number for display ──────────────────────────────────────
  String get maskedAccount {
    if (accountNumber.length <= 4) return accountNumber;
    final visible = accountNumber.substring(accountNumber.length - 4);
    final masked  = '•' * (accountNumber.length - 4);
    return '$masked$visible';
  }

  // ── Firestore ──────────────────────────────────────────────────────────────
  factory EmployeePaymentMethod.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return EmployeePaymentMethod(
      id:             doc.id,
      type:           EmpPayMethodTypeX.fromString(d['type'] as String?),
      accountNumber:  (d['accountNumber'] as String?) ?? '',
      accountName:    (d['accountName']   as String?) ?? '',
      bankName:       (d['bankName']      as String?) ?? '',
      branchName:     (d['branchName']    as String?) ?? '',
      routingNumber:  (d['routingNumber'] as String?) ?? '',
      isDefault:      (d['isDefault']     as bool?)   ?? false,
      isVerifiedByHr: (d['isVerifiedByHr'] as bool?)  ?? false,
      createdAt:      (d['createdAt']  as Timestamp?)?.toDate(),
      updatedAt:      (d['updatedAt']  as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type':          type.label,
        'accountNumber': accountNumber,
        'accountName':   accountName,
        'bankName':      bankName,
        'branchName':    branchName,
        'routingNumber': routingNumber,
        'isDefault':     isDefault,
        'isVerifiedByHr': isVerifiedByHr,
        'updatedAt':     FieldValue.serverTimestamp(),
      };

  EmployeePaymentMethod copyWith({
    String?           id,
    EmpPayMethodType? type,
    String?           accountNumber,
    String?           accountName,
    String?           bankName,
    String?           branchName,
    String?           routingNumber,
    bool?             isDefault,
    bool?             isVerifiedByHr,
  }) =>
      EmployeePaymentMethod(
        id:             id             ?? this.id,
        type:           type           ?? this.type,
        accountNumber:  accountNumber  ?? this.accountNumber,
        accountName:    accountName    ?? this.accountName,
        bankName:       bankName       ?? this.bankName,
        branchName:     branchName     ?? this.branchName,
        routingNumber:  routingNumber  ?? this.routingNumber,
        isDefault:      isDefault      ?? this.isDefault,
        isVerifiedByHr: isVerifiedByHr ?? this.isVerifiedByHr,
        createdAt:      createdAt,
        updatedAt:      updatedAt,
      );
}
