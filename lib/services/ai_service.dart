import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uddoygi/services/db.dart';
import 'package:uddoygi/services/local_storage_service.dart';

/// Uddoygi AI Service — Unified interface for LLM operations.
/// Currently powered by OpenAI (GPT-4o).
class AIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  
  // IMPORTANT: For production, these should be moved to a secure backend or Firebase Remote Config.
  // For the current modernization phase, we are using the provided key.
  static const String _apiKey = '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';

  /// Generates a response based on a prompt.
  /// Used for "Smart Action Center" and "Business Insights".
  static Future<String> chat(String prompt, {String systemPrompt = 'You are Uddoygi AI, a helpful assistant for a smart ERP system. Give concise, professional, and actionable business advice.'}) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': 'gpt-4o',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': prompt}
          ],
          'temperature': 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'] ?? 'No response generated.';
        
        // Log to Audit Trail
        _logInteraction(prompt, content);
        
        return content;
      } else {
        return 'AI Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'AI Connection Error: $e';
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
        'userName': user.displayName,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // Fail silently to avoid breaking UX
    }
  }

  /// Parses complex documents using GPT-4o.
  /// Used as a high-confidence fallback for the DocumentExtractor.
  static Future<Map<String, dynamic>> parseDocument(String ocrText) async {
    const systemPrompt = '''
You are a document extraction specialist. 
Extract the following fields from the provided OCR text and return ONLY a JSON object.
Fields: provider, total_amount, currency, date, transaction_id, status.
If a field is missing, use null.
''';

    final result = await chat(ocrText, systemPrompt: systemPrompt);
    try {
      // Find JSON block if LLM added markdown
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(result);
      if (jsonMatch != null) {
        return jsonDecode(jsonMatch.group(0)!);
      }
      return jsonDecode(result);
    } catch (e) {
      return {'error': 'Failed to parse AI response', 'raw': result};
    }
  }
}
