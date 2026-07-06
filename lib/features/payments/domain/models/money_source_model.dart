// lib/features/payments/domain/models/money_source_model.dart
//
// A "money source" is a funding account/wallet the company owner uses to
// initiate payments (e.g. bKash wallet, bank account, card).
// Managed entirely in-app — PipraPay itself does not have a money-source API.
// Firestore path: data/{companyId}/money_sources/{sourceId}
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

enum MoneySourceType { bkash, nagad, rocket, upay, bank, card, other }

extension MoneySourceTypeX on MoneySourceType {
  String get label => switch (this) {
        MoneySourceType.bkash  => 'bKash',
        MoneySourceType.nagad  => 'Nagad',
        MoneySourceType.rocket => 'Rocket',
        MoneySourceType.upay   => 'Upay',
        MoneySourceType.bank   => 'Bank Account',
        MoneySourceType.card   => 'Card',
        MoneySourceType.other  => 'Other',
      };

  static MoneySourceType fromString(String? s) => switch (s) {
        'bkash'  => MoneySourceType.bkash,
        'nagad'  => MoneySourceType.nagad,
        'rocket' => MoneySourceType.rocket,
        'upay'   => MoneySourceType.upay,
        'bank'   => MoneySourceType.bank,
        'card'   => MoneySourceType.card,
        _        => MoneySourceType.other,
      };
}

class MoneySourceModel {
  final String          id;
  final String          label;          // user-given name e.g. "My bKash"
  final MoneySourceType type;
  final String          accountNumber;  // mobile number or account no
  final String          accountName;
  final String          bankName;       // for bank type
  final String          branchName;
  final String          routingNumber;
  final bool            isDefault;
  final bool            isActive;
  final DateTime?       createdAt;
  final DateTime?       updatedAt;

  const MoneySourceModel({
    required this.id,
    required this.label,
    required this.type,
    required this.accountNumber,
    this.accountName   = '',
    this.bankName      = '',
    this.branchName    = '',
    this.routingNumber = '',
    this.isDefault     = false,
    this.isActive      = true,
    this.createdAt,
    this.updatedAt,
  });

  factory MoneySourceModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return MoneySourceModel(
      id:            doc.id,
      label:         m['label']         as String? ?? '',
      type:          MoneySourceTypeX.fromString(m['type'] as String?),
      accountNumber: m['accountNumber'] as String? ?? '',
      accountName:   m['accountName']   as String? ?? '',
      bankName:      m['bankName']      as String? ?? '',
      branchName:    m['branchName']    as String? ?? '',
      routingNumber: m['routingNumber'] as String? ?? '',
      isDefault:     m['isDefault']     as bool?   ?? false,
      isActive:      m['isActive']      as bool?   ?? true,
      createdAt:     (m['createdAt']    as Timestamp?)?.toDate(),
      updatedAt:     (m['updatedAt']    as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'label':         label,
        'type':          type.name,
        'accountNumber': accountNumber,
        'accountName':   accountName,
        'bankName':      bankName,
        'branchName':    branchName,
        'routingNumber': routingNumber,
        'isDefault':     isDefault,
        'isActive':      isActive,
        'updatedAt':     FieldValue.serverTimestamp(),
      };

  MoneySourceModel copyWith({
    String?          label,
    MoneySourceType? type,
    String?          accountNumber,
    String?          accountName,
    String?          bankName,
    String?          branchName,
    String?          routingNumber,
    bool?            isDefault,
    bool?            isActive,
  }) =>
      MoneySourceModel(
        id:            id,
        label:         label         ?? this.label,
        type:          type          ?? this.type,
        accountNumber: accountNumber ?? this.accountNumber,
        accountName:   accountName   ?? this.accountName,
        bankName:      bankName      ?? this.bankName,
        branchName:    branchName    ?? this.branchName,
        routingNumber: routingNumber ?? this.routingNumber,
        isDefault:     isDefault     ?? this.isDefault,
        isActive:      isActive      ?? this.isActive,
        createdAt:     createdAt,
      );
}
