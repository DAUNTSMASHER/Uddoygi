import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:http/http.dart' as http;
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

/// Uddoygi AI Assistant Service
/// Primary: Firebase Cloud Function (server-side aggregation + Gemini, no API key exposed)
/// Fallback: parallelized Firestore reads + Vercel proxy
class AIService {
  static const String _proxyUrl = "https://uddyogi-erp-pro-ai.vercel.app/api/chat";
  static const String _fallbackKey = 'AIzaSyBBsRLJ9Qoc80YrKTLx9blUlDFB0J5qpm8';
  static final String _apiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: _fallbackKey);

  static final genai.GenerativeModel _model = genai.GenerativeModel(
    model: 'gemini-3-flash-preview',
    apiKey: _apiKey,
    systemInstruction: genai.Content.system(
      'You are the Uddoygi AI Assistant, a specialized ERP intelligence. '
      'Be professional, concise, and use Markdown for structured data.'
    ),
  );

  // ── Pre-cached company context (loaded on login) ──────────────────────────
  static String? _cachedContext;
  static DateTime? _lastCacheTime;
  static const Duration _cacheDuration = Duration(minutes: 10);

  /// Pre-fetches and caches company analytics context on login.
  /// Call this from splash/login screens after successful auth.
  static Future<void> init({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedContext != null &&
        DateTime.now().difference(_lastCacheTime!) < _cacheDuration) {
      return; // cache still fresh
    }
    final cid = await LocalStorageService.getSavedCompanyId();
    if (cid == null || cid.isEmpty) return;
    try {
      _cachedContext = await _buildAnalyticsContext(cid);
      _lastCacheTime = DateTime.now();
    } catch (_) {
      // Silent fail — context will be built per‑request as fallback
    }
  }

  /// Builds analytics context string from Firestore.
  static Future<String> _buildAnalyticsContext(String cid) async {
    final snapshots = await Future.wait([
      DB.colSync(cid, C.invoices).limit(40).get(),
      DB.colSync(cid, C.workOrders).limit(30).get(),
      DB.colSync(cid, C.products).limit(30).get(),
      DB.colSync(cid, C.expenses).limit(30).get(),
    ]);

    double totalRev = 0, paidRev = 0, totalExp = 0;
    int pending = 0, done = 0, active = 0;
    final lowStock = <String>[];

    for (final doc in snapshots[0].docs) {
      final d = doc.data();
      final v = (d['totalAmount'] ?? d['amount'] ?? 0);
      final n = v is num ? v : (num.tryParse('$v') ?? 0);
      totalRev += n.toDouble();
      if ('${d['status']}'.toLowerCase().contains('paid') || '${d['status']}'.toLowerCase().contains('completed')) {
        paidRev += n.toDouble();
      } else {
        pending++;
      }
    }
    for (final doc in snapshots[1].docs) {
      final d = doc.data();
      if (d['completed'] == true || '${d['status']}'.toLowerCase() == 'completed') {
        done++;
      } else {
        active++;
      }
    }
    for (final doc in snapshots[2].docs) {
      final d = doc.data();
      final s = (d['stock'] ?? d['quantity'] ?? 0);
      final n = s is num ? s : (num.tryParse('$s') ?? 0);
      if (n < 10) lowStock.add('${d['name'] ?? 'Item'} ($n left)');
    }
    for (final doc in snapshots[3].docs) {
      final d = doc.data();
      final v = (d['amount'] ?? d['total'] ?? 0);
      final n = v is num ? v : (num.tryParse('$v') ?? 0);
      totalExp += n.toDouble();
    }

    return '''
[REAL-TIME COMPANY DATABASE ANALYTICS SNAPSHOT]
Company ID: $cid
- Invoiced Revenue: \$${totalRev.toStringAsFixed(2)} (\$${paidRev.toStringAsFixed(2)} collected, $pending unpaid)
- Work Orders: ${snapshots[1].docs.length} total ($done completed, $active running)
- Inventory: ${snapshots[2].docs.length} SKUs (Low Stock: ${lowStock.isEmpty ? 'None' : lowStock.take(5).join(', ')})
- Expenses: \$${totalExp.toStringAsFixed(2)}
- Net Cashflow: \$${(paidRev - totalExp).toStringAsFixed(2)}
[END ANALYTICS SNAPSHOT]
''';
  }

  /// Primary: call Cloud Function (server-side aggregation + AI).
  static Future<String> chat(String prompt, {List<Map<String, dynamic>>? history}) async {
    final cid = await LocalStorageService.getSavedCompanyId() ?? '';
    if (cid.isEmpty) return 'Please log in first to use the AI Assistant.';

    try {
      final fn = FirebaseFunctions.instance.httpsCallable('aiChat',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 15)));
      final result = await fn.call({
        'companyId': cid,
        'prompt': prompt,
        'history': history ?? [],
      });
      final data = result.data as Map<String, dynamic>;
      return data['text'] as String? ?? 'No response from AI.';
    } catch (_) {
      return _fallbackChat(prompt, cid);
    }
  }

  /// Fallback: cached context + Vercel proxy (or direct Gemini).
  static Future<String> _fallbackChat(String prompt, String cid) async {
    try {
      // Use cached context if fresh, else build on the fly
      final ctx = (_cachedContext != null &&
              DateTime.now().difference(_lastCacheTime!) < _cacheDuration)
          ? _cachedContext!
          : await _buildAnalyticsContext(cid);
      final fullPrompt = '$ctx\n\nUser Prompt: $prompt';

      // Try Vercel proxy first
      try {
        final response = await http.post(
          Uri.parse(_proxyUrl),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'prompt': fullPrompt, 'companyId': cid}),
        ).timeout(const Duration(seconds: 15));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['text'] ?? data['response'];
          if (text != null) return text;
        }
      } catch (_) {}

      // Final fallback: direct Gemini
      if (_apiKey.isNotEmpty && !_apiKey.contains('_fallbackKey')) {
        final chatSession = _model.startChat();
        final resp = await chatSession.sendMessage(genai.Content.text(fullPrompt));
        return resp.text ?? 'No response.';
      }
    } catch (_) {}
    return 'AI Assistant is busy. Please try again shortly.';
  }

  /// Parses OCR text into structured JSON using Gemini.
  static Future<Map<String, dynamic>> parseDocument(String ocrText) async {
    if (_apiKey.isEmpty) return {'error': 'API Key missing'};
    const prompt = 'Extract document_type, provider, reference_company, transaction_id, invoice_number, date, currency, total_amount, status as JSON from:';
    try {
      final response = await _model.generateContent([genai.Content.text('$prompt\n$ocrText')]);
      final text = response.text ?? '{}';
      return json.decode(text.replaceAll('```json', '').replaceAll('```', '').trim()) as Map<String, dynamic>;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<void> logInteraction(String prompt, String response) async {
    try {
      final cid = await LocalStorageService.getSavedCompanyId();
      final user = FirebaseAuth.instance.currentUser;
      if (cid == null || user == null) return;
      await DB.colSync(cid, 'ai_interactions').add({
        'prompt': prompt,
        'response': response,
        'userEmail': user.email,
        'model': 'gemini-3-flash-preview',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}