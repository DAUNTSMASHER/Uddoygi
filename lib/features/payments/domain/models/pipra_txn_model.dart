// lib/features/payments/domain/models/pipra_txn_model.dart
//
// Represents a single PipraPay transaction record.
// Created locally when a charge is initiated; updated via webhook/verify.
// Firestore path: data/{companyId}/pipra_transactions/{txnId}
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

enum TxnStatus { pending, processing, paid, failed, cancelled, refunded }

extension TxnStatusX on TxnStatus {
  String get label => switch (this) {
        TxnStatus.pending    => 'Pending',
        TxnStatus.processing => 'Processing',
        TxnStatus.paid       => 'Paid',
        TxnStatus.failed     => 'Failed',
        TxnStatus.cancelled  => 'Cancelled',
        TxnStatus.refunded   => 'Refunded',
      };

  static TxnStatus fromString(String? s) => switch (s?.toLowerCase()) {
        'completed' || 'paid'  => TxnStatus.paid,
        'processing'           => TxnStatus.processing,
        'failed'               => TxnStatus.failed,
        'cancelled'            => TxnStatus.cancelled,
        'refunded'             => TxnStatus.refunded,
        _                      => TxnStatus.pending,
      };
}

class PipraTxnModel {
  final String    id;           // Firestore doc id (also used as metadata.order_id)
  final String    ppId;         // PipraPay pp_id (set after webhook/verify)
  final String    invoiceId;    // PipraPay invoice_id (set after create-charge)
  final String    beneficiaryId;
  final String    beneficiaryName;
  final String    emailOrMobile;
  final double    amount;
  final double    fee;
  final double    total;
  final String    currency;
  final String    paymentMethod;
  final TxnStatus status;
  final String    notes;
  final String    senderNumber;
  final String    transactionId; // gateway-level txn id
  final bool      isSandbox;
  final Map<String, dynamic> metadata;
  final DateTime? initiatedAt;
  final DateTime? paidAt;
  final DateTime? updatedAt;

  const PipraTxnModel({
    required this.id,
    this.ppId            = '',
    this.invoiceId       = '',
    required this.beneficiaryId,
    required this.beneficiaryName,
    required this.emailOrMobile,
    required this.amount,
    this.fee             = 0,
    this.total           = 0,
    this.currency        = 'BDT',
    this.paymentMethod   = '',
    this.status          = TxnStatus.pending,
    this.notes           = '',
    this.senderNumber    = '',
    this.transactionId   = '',
    this.isSandbox       = true,
    this.metadata        = const {},
    this.initiatedAt,
    this.paidAt,
    this.updatedAt,
  });

  factory PipraTxnModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? {};
    return PipraTxnModel(
      id:              doc.id,
      ppId:            m['ppId']            as String? ?? '',
      invoiceId:       m['invoiceId']       as String? ?? '',
      beneficiaryId:   m['beneficiaryId']   as String? ?? '',
      beneficiaryName: m['beneficiaryName'] as String? ?? '',
      emailOrMobile:   m['emailOrMobile']   as String? ?? '',
      amount:          _toDouble(m['amount']),
      fee:             _toDouble(m['fee']),
      total:           _toDouble(m['total']),
      currency:        m['currency']        as String? ?? 'BDT',
      paymentMethod:   m['paymentMethod']   as String? ?? '',
      status:          TxnStatusX.fromString(m['status'] as String?),
      notes:           m['notes']           as String? ?? '',
      senderNumber:    m['senderNumber']    as String? ?? '',
      transactionId:   m['transactionId']   as String? ?? '',
      isSandbox:       m['isSandbox']       as bool?   ?? true,
      metadata:        (m['metadata'] as Map?)?.cast<String, dynamic>() ?? {},
      initiatedAt:     (m['initiatedAt'] as Timestamp?)?.toDate(),
      paidAt:          (m['paidAt']      as Timestamp?)?.toDate(),
      updatedAt:       (m['updatedAt']   as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ppId':            ppId,
        'invoiceId':       invoiceId,
        'beneficiaryId':   beneficiaryId,
        'beneficiaryName': beneficiaryName,
        'emailOrMobile':   emailOrMobile,
        'amount':          amount,
        'fee':             fee,
        'total':           total,
        'currency':        currency,
        'paymentMethod':   paymentMethod,
        'status':          status.name,
        'notes':           notes,
        'senderNumber':    senderNumber,
        'transactionId':   transactionId,
        'isSandbox':       isSandbox,
        'metadata':        metadata,
        'initiatedAt':     initiatedAt == null
            ? FieldValue.serverTimestamp()
            : Timestamp.fromDate(initiatedAt!),
        'paidAt':    paidAt == null ? null : Timestamp.fromDate(paidAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  PipraTxnModel copyWith({
    String?    ppId,
    String?    invoiceId,
    double?    fee,
    double?    total,
    String?    paymentMethod,
    TxnStatus? status,
    String?    senderNumber,
    String?    transactionId,
    DateTime?  paidAt,
    Map<String, dynamic>? metadata,
  }) =>
      PipraTxnModel(
        id:              id,
        ppId:            ppId            ?? this.ppId,
        invoiceId:       invoiceId       ?? this.invoiceId,
        beneficiaryId:   beneficiaryId,
        beneficiaryName: beneficiaryName,
        emailOrMobile:   emailOrMobile,
        amount:          amount,
        fee:             fee             ?? this.fee,
        total:           total           ?? this.total,
        currency:        currency,
        paymentMethod:   paymentMethod   ?? this.paymentMethod,
        status:          status          ?? this.status,
        notes:           notes,
        senderNumber:    senderNumber    ?? this.senderNumber,
        transactionId:   transactionId   ?? this.transactionId,
        isSandbox:       isSandbox,
        metadata:        metadata        ?? this.metadata,
        initiatedAt:     initiatedAt,
        paidAt:          paidAt          ?? this.paidAt,
      );

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
