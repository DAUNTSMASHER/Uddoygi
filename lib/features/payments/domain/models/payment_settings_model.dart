// lib/features/payments/domain/models/payment_settings_model.dart
//
// PipraPay integration settings stored per company.
// Firestore path: data/{companyId}/payment_settings/piprapay
// ─────────────────────────────────────────────────────────────────────────────

import 'package:cloud_firestore/cloud_firestore.dart';

class PaymentSettingsModel {
  final bool   enabled;
  final bool   sandboxMode;
  final String backendBaseUrl;   // e.g. https://api.yourserver.com — never store keys here
  final String currency;         // default: BDT
  final String defaultRedirectUrl;
  final String defaultCancelUrl;
  final String defaultWebhookUrl;
  final String connectionStatus; // 'connected' | 'disconnected' | 'pending'
  final DateTime? lastVerifiedAt;
  final DateTime? updatedAt;

  const PaymentSettingsModel({
    this.enabled            = false,
    this.sandboxMode        = true,
    this.backendBaseUrl     = '',
    this.currency           = 'BDT',
    this.defaultRedirectUrl = '',
    this.defaultCancelUrl   = '',
    this.defaultWebhookUrl  = '',
    this.connectionStatus   = 'disconnected',
    this.lastVerifiedAt,
    this.updatedAt,
  });

  factory PaymentSettingsModel.fromMap(Map<String, dynamic> m) =>
      PaymentSettingsModel(
        enabled:            m['enabled']            as bool?  ?? false,
        sandboxMode:        m['sandboxMode']        as bool?  ?? true,
        backendBaseUrl:     m['backendBaseUrl']     as String? ?? '',
        currency:           m['currency']           as String? ?? 'BDT',
        defaultRedirectUrl: m['defaultRedirectUrl'] as String? ?? '',
        defaultCancelUrl:   m['defaultCancelUrl']   as String? ?? '',
        defaultWebhookUrl:  m['defaultWebhookUrl']  as String? ?? '',
        connectionStatus:   m['connectionStatus']   as String? ?? 'disconnected',
        lastVerifiedAt:     (m['lastVerifiedAt'] as Timestamp?)?.toDate(),
        updatedAt:          (m['updatedAt']      as Timestamp?)?.toDate(),
      );

  Map<String, dynamic> toMap() => {
        'enabled':            enabled,
        'sandboxMode':        sandboxMode,
        'backendBaseUrl':     backendBaseUrl,
        'currency':           currency,
        'defaultRedirectUrl': defaultRedirectUrl,
        'defaultCancelUrl':   defaultCancelUrl,
        'defaultWebhookUrl':  defaultWebhookUrl,
        'connectionStatus':   connectionStatus,
        'lastVerifiedAt':     lastVerifiedAt == null
            ? null
            : Timestamp.fromDate(lastVerifiedAt!),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  PaymentSettingsModel copyWith({
    bool?   enabled,
    bool?   sandboxMode,
    String? backendBaseUrl,
    String? currency,
    String? defaultRedirectUrl,
    String? defaultCancelUrl,
    String? defaultWebhookUrl,
    String? connectionStatus,
    DateTime? lastVerifiedAt,
  }) =>
      PaymentSettingsModel(
        enabled:            enabled            ?? this.enabled,
        sandboxMode:        sandboxMode        ?? this.sandboxMode,
        backendBaseUrl:     backendBaseUrl     ?? this.backendBaseUrl,
        currency:           currency           ?? this.currency,
        defaultRedirectUrl: defaultRedirectUrl ?? this.defaultRedirectUrl,
        defaultCancelUrl:   defaultCancelUrl   ?? this.defaultCancelUrl,
        defaultWebhookUrl:  defaultWebhookUrl  ?? this.defaultWebhookUrl,
        connectionStatus:   connectionStatus   ?? this.connectionStatus,
        lastVerifiedAt:     lastVerifiedAt     ?? this.lastVerifiedAt,
      );
}
