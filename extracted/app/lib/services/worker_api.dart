import '../utils/app_labels.dart';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

/// Shared authenticated Cloudflare Worker client.
class WorkerApi {
  static const String baseUrl =
      'https://sanchore-bazaar-api.kamlesh9828-kp.workers.dev';

  /// Public endpoints (kept for compatibility; customer registration no longer uses OTP).
  static Future<Map<String, dynamic>> postPublic(
    String endpoint,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: const <String, String>{'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(timeout);

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw Exception('सर्वर से सही जवाब नहीं मिला।');
    }
    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300 ||
        data['success'] == false) {
      throw Exception(AppLabels.serverError(data['error'] ?? data['message'] ?? ''));
    }
    return data;
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('लॉगिन जरूरी है।');

    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('लॉगिन टोकन नहीं मिला। दोबारा लॉगिन करें।');
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl$endpoint'),
          headers: <String, String>{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw Exception('सर्वर से सही जवाब नहीं मिला।');
    }

    final data = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] == false) {
      final error = data['error'] ?? data['message'];
      throw Exception(AppLabels.serverError(error ?? ''));
    }

    return data;
  }
}
