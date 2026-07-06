import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart' as genai;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

/// Uddoygi AI Assistant Service
/// Optimized for multi-device accuracy and production stability.
class AIService {
  // UNIQUE PRODUCTION URL: Specifically for this project to ensure no conflicts
  static const String _proxyUrl = "https://uddyogi-erp-pro-ai.vercel.app/api/chat";

  static const String _fallbackKey = 'AIzaSyBBsRLJ9Qoc80YrKTLx9blUlDFB0J5qpm8';
  static final String _apiKey = const String.fromEnvironment('GEMINI_API_KEY', defaultValue: _fallbackKey);
  
  // Requirement: Use gemini-3-flash for next-gen speed and accuracy
  static const String _modelName = 'gemini-3-flash-preview';

  static final genai.GenerativeModel _model = genai.GenerativeModel(
    model: _modelName,
    apiKey: _apiKey,
    systemInstruction: genai.Content.system(
      'You are the Uddoygi AI Assistant, a specialized ERP intelligence for Uddyogi ERP. '
      'Your purpose is to assist with employee management, HR policy queries, attendance summaries, '
      'marketing insights, and factory workflow optimization. '
      'Maintain a professional, helpful, and concise tone. Use Markdown for structured data. '
      'Context: You are responding to users within their specific company dashboard. '
      'If asked about non-business topics, politely steer the conversation back to ERP and productivity.'
    ),
  );

  /// Aggregates real-time Firestore database metrics (invoices, work orders, expenses, stock)
  /// for the given company so the AI can analyze financial and operational performance.
  static Future<String> _fetchCompanyAnalyticsContext(String cid) async {
    if (cid.isEmpty || cid == 'Unknown') return '';
    try {
      // 1. Invoices / Sales Revenue
      final invSnap = await DB.colSync(cid, C.invoices).limit(40).get();
      double totalRev = 0;
      double paidRev = 0;
      int pendingCount = 0;
      for (final doc in invSnap.docs) {
        final data = doc.data();
        final amount = (data['totalAmount'] ?? data['amount'] ?? 0);
        final num val = amount is num ? amount : (num.tryParse(amount.toString()) ?? 0);
        totalRev += val.toDouble();
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (status == 'paid' || status == 'completed') {
          paidRev += val.toDouble();
        } else {
          pendingCount++;
        }
      }

      // 2. Work Orders / Factory
      final woSnap = await DB.colSync(cid, C.workOrders).limit(30).get();
      int totalWo = woSnap.docs.length;
      int completedWo = 0;
      int runningWo = 0;
      for (final doc in woSnap.docs) {
        final data = doc.data();
        final comp = data['completed'] == true || (data['status'] ?? '').toString().toLowerCase() == 'completed';
        if (comp) completedWo++; else runningWo++;
      }

      // 3. Products & Stock Warnings
      final prodSnap = await DB.colSync(cid, C.products).limit(30).get();
      int totalProducts = prodSnap.docs.length;
      List<String> lowStockItems = [];
      for (final doc in prodSnap.docs) {
        final data = doc.data();
        final stock = data['stock'] ?? data['quantity'] ?? 0;
        final num sVal = stock is num ? stock : (num.tryParse(stock.toString()) ?? 0);
        if (sVal < 10) {
          lowStockItems.add("${data['name'] ?? 'Item'} ($sVal left)");
        }
      }

      // 4. Expenses
      final expSnap = await DB.colSync(cid, C.expenses).limit(30).get();
      double totalExp = 0;
      for (final doc in expSnap.docs) {
        final data = doc.data();
        final amount = data['amount'] ?? data['total'] ?? 0;
        final num val = amount is num ? amount : (num.tryParse(amount.toString()) ?? 0);
        totalExp += val.toDouble();
      }

      return '''

[REAL-TIME COMPANY DATABASE ANALYTICS SNAPSHOT - RECENT MONTHS]
Company ID: $cid
- Total Invoiced Revenue: \$${totalRev.toStringAsFixed(2)} (\$${paidRev.toStringAsFixed(2)} collected, $pendingCount unpaid/pending invoices)
- Work Orders Performance: $totalWo total orders ($completedWo completed, $runningWo active/running)
- Inventory Status: $totalProducts active SKUs (Low Stock Alerts: ${lowStockItems.isEmpty ? 'None' : lowStockItems.take(5).join(', ')})
- Total Recorded Expenses: \$${totalExp.toStringAsFixed(2)}
- Net Estimated Operating Cashflow: \$${(paidRev - totalExp).toStringAsFixed(2)}
[END ANALYTICS SNAPSHOT]
''';
    } catch (e) {
      return '[Analytics Snapshot Notice: Could not aggregate database metrics ($e)]';
    }
  }

  /// Generates a response based on a prompt with multi-device context support.
  static Future<String> chat(String prompt, {List<genai.Content>? history}) async {
    final cid = await LocalStorageService.getSavedCompanyId() ?? 'Unknown';
    final user = FirebaseAuth.instance.currentUser;
    
    // Fetch live financial & operational database analytics for this company
    final analyticsSnapshot = await _fetchCompanyAnalyticsContext(cid);

    // REQUIREMENT: High Accuracy across different devices
    // We inject the company context and live database snapshot into every request
    final contextualPrompt = "[Context: CompanyID=$cid, User=${user?.displayName ?? 'Employee'}]$analyticsSnapshot\n\nUser Prompt: $prompt";

    // 1. Try Global Proxy (Best for multi-device stability)
    if (_proxyUrl.isNotEmpty && _proxyUrl.startsWith('http')) {
      try {
        final response = await http.post(
          Uri.parse(_proxyUrl),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "prompt": contextualPrompt,
            "companyId": cid,
            "history": history?.map((c) => {
              "role": c.role,
              "parts": c.parts.whereType<genai.TextPart>().map((p) => p.text).toList()
            }).toList(),
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['text'] ?? data['response'] ?? 'Empty response from proxy.';
        }
      } catch (e) {
        // Fallback to direct Gemini if proxy is down
      }
    }

    // 2. Direct Gemini Call (Fallback)
    return _directChat(contextualPrompt, history: history);
  }

  static Future<String> _directChat(String prompt, {List<genai.Content>? history}) async {
    if (_apiKey.isEmpty) return 'Error: Gemini API Key is missing. Please check configuration.';
    
    try {
      final chatSession = _model.startChat(history: history);
      final response = await chatSession.sendMessage(genai.Content.text(prompt));
      
      final text = response.text ?? 'I apologize, I could not process that request.';
      _logInteraction(prompt, text);
      return text;
    } catch (e) {
      final err = e.toString().toLowerCase();
      if (err.contains('quota') || err.contains('429')) {
        return 'The daily AI limit is reached. Please try again in a few minutes.';
      } else if (err.contains('api_key') || err.contains('403')) {
        return 'Invalid API configuration. Please ensure the GEMINI_API_KEY is valid.';
      }
      return 'AI Assistant is currently busy. Please try again shortly.';
    }
  }

  /// Parses OCR text into a structured JSON map for document extraction.
  static Future<Map<String, dynamic>> parseDocument(String ocrText) async {
    if (_apiKey.isEmpty) return {'error': 'API Key missing'};

    final prompt = '''
Extract the following information from this OCR text and return it as a JSON object:
- document_type (receipt, invoice, etc.)
- provider (the merchant or service name)
- reference_company (any other company mentioned)
- transaction_id
- invoice_number
- date
- currency
- total_amount (numeric only)
- status (completed, pending, etc.)

Return ONLY the JSON object. No other text.

OCR TEXT:
$ocrText
''';

    try {
      final response = await _model.generateContent([genai.Content.text(prompt)]);
      final text = response.text ?? '{}';
      final jsonStr = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return json.decode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<void> _logInteraction(String prompt, String response) async {
    try {
      final cid = await LocalStorageService.getSavedCompanyId();
      final user = FirebaseAuth.instance.currentUser;
      if (cid == null || user == null) return;

      await DB.colSync(cid, 'ai_interactions').add({
        'prompt': prompt,
        'response': response,
        'userEmail': user.email,
        'model': _modelName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
