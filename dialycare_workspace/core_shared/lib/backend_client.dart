import 'dart:convert';

import 'package:http/http.dart' as http;

/// The same authenticated API is used by both frontends. No server secrets.
class BackendClient {
  BackendClient({
    required this.token,
    this.endpoint = const String.fromEnvironment(
      'DIALYCARE_API_URL',
      defaultValue:
          'https://us-central1-dialycare-backend-3f0ed.cloudfunctions.net/api',
    ),
  });
  final Future<String?> Function() token;
  final String endpoint;
  bool get configured => Uri.tryParse(endpoint)?.scheme == 'https';
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (!configured) {
      throw const BackendException(
        'The care center connection needs setup. Please contact your center.',
      );
    }
    final bearer = await token();
    final response = await http
        .post(
          Uri.parse('$endpoint/$action'),
          headers: {
            'Content-Type': 'application/json',
            if (bearer != null) 'Authorization': 'Bearer $bearer',
          },
          body: jsonEncode(data),
        )
        .timeout(const Duration(seconds: 25));
    Map<String, dynamic> body;
    try {
      body = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    } catch (_) {
      throw const BackendException(
        'The care center could not be reached. Please try again.',
      );
    }
    if (response.statusCode != 200) {
      throw BackendException(
        body['error'] as String? ?? 'Request failed. Please try again.',
        response.statusCode,
      );
    }
    return body;
  }
}

class BackendException implements Exception {
  const BackendException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

/// Developer diagnostics contain request metadata, never credentials or bodies.
class FirestoreFailure extends BackendException {
  const FirestoreFailure(
    super.message,
    super.statusCode, {
    required this.code,
    required this.operation,
    required this.resources,
    required this.uid,
    required this.role,
    required this.firebaseMessage,
  });
  final String code, operation, uid, role, firebaseMessage;
  final List<String> resources;
}

String accountEmail(String role, String id) {
  if (!['patient', 'relative'].contains(role)) {
    throw const BackendException('Choose Patient or Relative.');
  }
  final normalized = id.trim().toLowerCase();
  if (!RegExp(r'^[a-z0-9-]{2,100}$').hasMatch(normalized)) {
    throw const BackendException(
      'Enter the account ID supplied by your care center.',
    );
  }
  return '$normalized@$role.dialycare.invalid';
}
