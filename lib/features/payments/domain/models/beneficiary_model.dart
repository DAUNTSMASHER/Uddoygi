// lib/features/payments/domain/models/beneficiary_model.dart
//
// A beneficiary is a person/entity the company sends money to.
// Managed in-app; PipraPay processes the actual transaction.
// Firestore path: data/{companyId}/beneficiaries/{beneficiaryId}
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

enum BeneficiaryType { individual, vendor, employee, other }

extension BeneficiaryTypeX on BeneficiaryType {
  String get label => switch (this) {
        BeneficiaryType.individual => 'Individual',
        BeneficiaryType.vendor     => 'Vendor',
        BeneficiaryType.employee   => 'Employee',
        BeneficiaryType.other      => 'Other',
      };

  static BeneficiaryType fromString(String? s) => switch (s) {
        'individual' => BeneficiaryType.individual,
        'vendor'     => BeneficiaryType.vendor,
        'employee'   => BeneficiaryType.employee,
        _            => BeneficiaryType.other,
      };
}

class BeneficiaryModel {
  final String          id;
  final String          name;
  final BeneficiaryType type;
  final String          emailOrMobile;  // used as PipraPay's email_mobile field
  final String          accountNumber;  // wallet / bank account
  final String          bankName;
  final String          notes;
  final bool            isActive;
  final DateTime?       createdAt;
  final DateTime?       updatedAt;

  const BeneficiaryModel({
    required this.id,
    required this.name,
    required this.emailOrMobile,
    this.type          = BeneficiaryType.individual,
    this.accountNumber = '',
    this.bankName      = '',
    this.notes         = '',
    this.isActive      = true,
    this.createdAt,
    this.updatedAt,
  });

  factory BeneficiaryModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return BeneficiaryModel(
      id:            doc.id,
      name:          m['name']          as String? ?? '',
      emailOrMobile: m['emailOrMobile'] as String? ?? '',
      type:          BeneficiaryTypeX.fromString(m['type'] as String?),
      accountNumber: m['accountNumber'] as String? ?? '',
      bankName:      m['bankName']      as String? ?? '',
      notes:         m['notes']         as String? ?? '',
      isActive:      m['isActive']      as bool?   ?? true,
      createdAt:     (m['createdAt']    as Timestamp?)?.toDate(),
      updatedAt:     (m['updatedAt']    as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name':          name,
        'emailOrMobile': emailOrMobile,
        'type':          type.name,
        'accountNumber': accountNumber,
        'bankName':      bankName,
        'notes':         notes,
        'isActive':      isActive,
        'updatedAt':     FieldValue.serverTimestamp(),
      };

  BeneficiaryModel copyWith({
    String?          name,
    String?          emailOrMobile,
    BeneficiaryType? type,
    String?          accountNumber,
    String?          bankName,
    String?          notes,
    bool?            isActive,
  }) =>
      BeneficiaryModel(
        id:            id,
        name:          name          ?? this.name,
        emailOrMobile: emailOrMobile ?? this.emailOrMobile,
        type:          type          ?? this.type,
        accountNumber: accountNumber ?? this.accountNumber,
        bankName:      bankName      ?? this.bankName,
        notes:         notes         ?? this.notes,
        isActive:      isActive      ?? this.isActive,
        createdAt:     createdAt,
      );
}
