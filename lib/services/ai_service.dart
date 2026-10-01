import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../utils/app_exception.dart';

class AiDraft {
  const AiDraft({required this.draft, required this.missingDetails});
  final String draft;
  final List<String> missingDetails;
}

/// Calls the Cloud Function proxy (see functions/index.js). The LLM API key
/// never lives in the app. Build with:
///   flutter run --dart-define=AI_ENDPOINT=https://<your-function-url>
/// Only the client ALIAS and the free-text description are sent.
class AiService {
  static const String endpoint = String.fromEnvironment('AI_ENDPOINT');

  bool get isConfigured => endpoint.isNotEmpty;

  Future<AiDraft> improve({
    required String category,
    required String severity,
    required String clientAlias,
    required String text,
  }) async {
    if (!isConfigured) {
      throw AppException('AI drafting is not configured in this build.');
    }
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final res = await http
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'category': category,
              'severity': severity,
              'client': clientAlias,
              'text': text,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode != 200) {
        throw AppException(
            'The AI suggestion is unavailable right now. You can continue without it.');
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final draft = (data['draft'] as String?)?.trim() ?? '';
      if (draft.isEmpty) {
        throw AppException('The AI did not return a usable suggestion.');
      }
      final missing = (data['missing_details'] as List? ?? const [])
          .map((e) => e.toString())
          .toList();
      return AiDraft(draft: draft, missingDetails: missing);
    } on AppException {
      rethrow;
    } catch (_) {
      throw AppException(
          'The AI suggestion could not be loaded. You can continue without it.');
    }
  }
}
