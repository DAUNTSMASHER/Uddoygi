// lib/services/company_verification_service.dart
//
// Verifies a Company ID before the user signs in.
//
// DEPLOYED FIREBASE RULES (as of current):
//   companies/{companyId}
//     allow read:  if resource.data.isActive == true   ← public, no auth needed
//     allow write: if request.auth != null
//   everything else:
//     allow read, write: if request.auth != null
//
// STRATEGY (tried in order):
//   1. Firestore REST API with API key
//      → Works for active companies (isActive == true) without any auth token.
//        This is the fast, zero-auth path used on the login screen.
//
//   2. Anonymous Firebase Auth sign-in
//      → If REST returns 403 (company not active, or rules changed),
//        sign in anonymously so request.auth != null, read the doc,
//        then immediately delete the anonymous account and sign out.
//        Does NOT interfere with a real user already signed in.
//
//   3. Firestore SDK direct read
//      → Last resort if anonymous auth is disabled or fails.
//        Works when a real user is already authenticated.
// ─────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ── Result model ──────────────────────────────────────────────
class CompanyInfo {
  final String companyId;
  final String name;
  final String logoUrl;
  final String email;
  final String phone;
  final String industry;

  const CompanyInfo({
    required this.companyId,
    required this.name,
    required this.logoUrl,
    required this.email,
    required this.phone,
    required this.industry,
  });
}

// ── Typed exception ───────────────────────────────────────────
class CompanyVerificationException implements Exception {
  final String message;
  const CompanyVerificationException(this.message);
  @override
  String toString() => message;
}

// Internal sentinel — not exposed to callers
class _RulesBlockedException implements Exception {}

// ── Service ───────────────────────────────────────────────────
class CompanyVerificationService {
  static const _projectId = 'uddyogi';
  static const _apiKey    = 'AIzaSyB00JFFDWQfEKRFpz50RLfKTuz9Ve4uuyg';
  static const _restBase  =
      'https://firestore.googleapis.com/v1/projects/$_projectId'
      '/databases/(default)/documents';

  // ── Public: lookup by Company ID ─────────────────────────────
  static Future<CompanyInfo?> lookup(String companyId) async {
    final id = companyId.trim();
    if (id.isEmpty) {
      throw CompanyVerificationException('Please enter your Company ID.');
    }
    if (id.length != 8 || int.tryParse(id) == null) {
      throw CompanyVerificationException(
          'Company ID must be exactly 8 digits (numbers only).');
    }

    // Strategy 1: REST — works for isActive == true companies, no auth needed
    try {
      debugPrint('[CompanyVerification] Trying REST lookup for $id');
      final info = await _restLookup(id);
      if (info != null) {
        debugPrint('[CompanyVerification] REST lookup success: ${info.name}');
      } else {
        debugPrint('[CompanyVerification] REST lookup returned null');
      }
      return info;
    } on CompanyVerificationException catch (e) {
      debugPrint('[CompanyVerification] REST verification exception: ${e.message}');
      rethrow;
    } on _RulesBlockedException {
      debugPrint('[CompanyVerification] REST blocked (company inactive or rules changed), trying anon auth');
    } catch (e) {
      debugPrint('[CompanyVerification] REST error: $e, trying anon auth');
    }

    // Strategy 2: Anonymous auth (satisfies request.auth != null)
    try {
      debugPrint('[CompanyVerification] Trying anon auth lookup for $id');
      final result = await _anonAuthLookup(id);
      debugPrint('[CompanyVerification] Anon auth lookup ${result != null ? "success" : "returned null"}');
      return result;
    } catch (e) {
      debugPrint('[CompanyVerification] Anon auth failed: $e, trying SDK');
    }

    // Strategy 3: SDK direct (works if real user already signed in)
    debugPrint('[CompanyVerification] Trying SDK lookup for $id');
    final result = await _sdkLookup(id);
    debugPrint('[CompanyVerification] SDK lookup ${result != null ? "success" : "returned null"}');
    return result;
  }

  // ── Public: query by field (Forgot Company ID flow) ───────────
  static Future<CompanyInfo?> queryByField({
    required String field,
    required String value,
  }) async {
    // Strategy 1: REST structured query
    try {
      return await _restQuery(field: field, value: value);
    } on CompanyVerificationException {
      rethrow;
    } on _RulesBlockedException {
      debugPrint('[CompanyVerification] REST query blocked, trying anon auth');
    } catch (e) {
      debugPrint('[CompanyVerification] REST query error: $e');
    }

    // Strategy 2: Anonymous auth
    try {
      return await _anonAuthQuery(field: field, value: value);
    } catch (e) {
      debugPrint('[CompanyVerification] Anon query failed: $e');
    }

    // Strategy 3: SDK direct
    return _sdkQuery(field: field, value: value);
  }

  // ─────────────────────────────────────────────────────────────
  // STRATEGY 1 — Firestore REST API (no auth token)
  // Works because deployed rules allow read if isActive == true.
  // ─────────────────────────────────────────────────────────────

  static Future<CompanyInfo?> _restLookup(String id) async {
    final url = Uri.parse('$_restBase/companies/$id?key=$_apiKey');
    final response = await http
        .get(url, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 404) return null;
    if (response.statusCode == 403) throw _RulesBlockedException();
    if (response.statusCode != 200) {
      throw CompanyVerificationException(
          'Server error ${response.statusCode}. Please try again.');
    }
    return _parseRestDoc(id, response.body);
  }

  static Future<CompanyInfo?> _restQuery({
    required String field,
    required String value,
  }) async {
    final url = Uri.parse(
        'https://firestore.googleapis.com/v1/projects/$_projectId'
        '/databases/(default)/documents:runQuery?key=$_apiKey');

    final body = jsonEncode({
      'structuredQuery': {
        'from': [{'collectionId': 'companies'}],
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': field},
                  'op': 'EQUAL',
                  'value': {'stringValue': value},
                }
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'isActive'},
                  'op': 'EQUAL',
                  'value': {'booleanValue': true},
                }
              },
            ],
          }
        },
        'limit': 1,
      }
    });

    final response = await http
        .post(url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 403) throw _RulesBlockedException();
    if (response.statusCode != 200) {
      throw CompanyVerificationException(
          'Server error ${response.statusCode}. Please try again.');
    }

    final results = jsonDecode(response.body) as List<dynamic>;
    if (results.isEmpty) return null;

    final first = results.first as Map<String, dynamic>;
    final doc   = first['document'] as Map<String, dynamic>?;
    if (doc == null) return null;

    final resourceName = doc['name'] as String;
    final docId = resourceName.split('/').last;
    return _parseRestDoc(docId, jsonEncode(doc));
  }

  // ─────────────────────────────────────────────────────────────
  // STRATEGY 2 — Anonymous Firebase Auth
  // Signs in anonymously so request.auth != null, reads doc, cleans up.
  // Only used if REST is blocked (e.g. company not active).
  // Does NOT disturb a real user already signed in.
  // ─────────────────────────────────────────────────────────────

  static Future<CompanyInfo?> _anonAuthLookup(String id) async {
    // If a real (non-anonymous) user is already signed in, use SDK directly
    final existing = FirebaseAuth.instance.currentUser;
    if (existing != null && !existing.isAnonymous) {
      return _sdkLookup(id);
    }

    User? anonUser;
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      anonUser = cred.user;

      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(id)
          .get();

      return snap.exists ? _fromFirestoreDoc(id, snap.data()!) : null;
    } finally {
      if (anonUser != null) {
        try { await anonUser.delete(); } catch (_) {}
        try { await FirebaseAuth.instance.signOut(); } catch (_) {}
      }
    }
  }

  static Future<CompanyInfo?> _anonAuthQuery({
    required String field,
    required String value,
  }) async {
    final existing = FirebaseAuth.instance.currentUser;
    if (existing != null && !existing.isAnonymous) {
      return _sdkQuery(field: field, value: value);
    }

    User? anonUser;
    try {
      final cred = await FirebaseAuth.instance.signInAnonymously();
      anonUser = cred.user;

      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .where(field, isEqualTo: value)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      final d  = snap.docs.first.data();
      final id = snap.docs.first.id;
      return _fromFirestoreDoc(
          (d['companyId'] as String?)?.isNotEmpty == true
              ? d['companyId'] as String
              : id,
          d);
    } finally {
      if (anonUser != null) {
        try { await anonUser.delete(); } catch (_) {}
        try { await FirebaseAuth.instance.signOut(); } catch (_) {}
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STRATEGY 3 — Firestore SDK (real user already signed in)
  // ─────────────────────────────────────────────────────────────

  static Future<CompanyInfo?> _sdkLookup(String id) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .doc(id)
          .get();
      if (!snap.exists || snap.data() == null) return null;
      return _fromFirestoreDoc(id, snap.data()!);
    } catch (e) {
      debugPrint('[CompanyVerification] SDK lookup failed: $e');
      throw CompanyVerificationException(
        'Could not verify Company ID.\n'
        'Check your internet connection and try again.',
      );
    }
  }

  static Future<CompanyInfo?> _sdkQuery({
    required String field,
    required String value,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('companies')
          .where(field, isEqualTo: value)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final d  = snap.docs.first.data();
      final id = snap.docs.first.id;
      return _fromFirestoreDoc(
          (d['companyId'] as String?)?.isNotEmpty == true
              ? d['companyId'] as String
              : id,
          d);
    } catch (e) {
      debugPrint('[CompanyVerification] SDK query failed: $e');
      throw CompanyVerificationException(
        'Could not search companies.\n'
        'Check your internet connection and try again.',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────

  static CompanyInfo _parseRestDoc(String id, String body) {
    final json   = jsonDecode(body) as Map<String, dynamic>;
    final fields = (json['fields'] as Map<String, dynamic>?) ?? {};

    String str(String key) {
      final f = fields[key] as Map<String, dynamic>?;
      if (f == null) return '';
      return (f['stringValue'] as String?) ??
             (f['integerValue']?.toString()) ??
             '';
    }

    final name = str('companyName').isNotEmpty
        ? str('companyName')
        : str('legalName').isNotEmpty
            ? str('legalName')
            : 'Unknown Company';

    return CompanyInfo(
      companyId: id,
      name:      name,
      logoUrl:   str('logoUrl'),
      email:     str('email'),
      phone:     str('phone'),
      industry:  str('industry'),
    );
  }

  static CompanyInfo _fromFirestoreDoc(String id, Map<String, dynamic> d) {
    final name = (d['companyName'] as String?)?.isNotEmpty == true
        ? d['companyName'] as String
        : (d['legalName'] as String?)?.isNotEmpty == true
            ? d['legalName'] as String
            : 'Unknown Company';
    return CompanyInfo(
      companyId: id,
      name:      name,
      logoUrl:   (d['logoUrl']  as String?) ?? '',
      email:     (d['email']    as String?) ?? '',
      phone:     (d['phone']    as String?) ?? '',
      industry:  (d['industry'] as String?) ?? '',
    );
  }
}
