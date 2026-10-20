import 'dart:convert';

import 'package:http/http.dart' as http;

import 'backend_client.dart';

/// In-memory Firebase email/password session for the Windows Staff frontend.
/// Refresh tokens never enter the clinical workspace or local JSON storage.
class PasswordIdentity {
  PasswordIdentity(this.apiKey, {http.Client? client})
    : _client = client ?? http.Client();
  final String apiKey;
  final http.Client _client;
  String? _idToken, _refreshToken;
  String? uid;
  DateTime _expires = DateTime(2000);
  Future<void> signIn(String email, String password) async {
    signOut();
    final response = await _client
        .post(
          Uri.https(
            'identitytoolkit.googleapis.com',
            '/v1/accounts:signInWithPassword',
            {'key': apiKey},
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'returnSecureToken': true,
          }),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      String? code;
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        code = (body['error'] as Map?)?['message'] as String?;
      } catch (_) {
        // Never display raw provider responses or supplied credentials.
      }
      throw BackendException(switch (code) {
        'CONFIGURATION_NOT_FOUND' || 'OPERATION_NOT_ALLOWED' => 'Email/Password sign-in needs to be enabled in the DialyCare Firebase project.',
        'TOO_MANY_ATTEMPTS_TRY_LATER' =>
          'Too many sign-in attempts. Please wait and try again.',
        'USER_DISABLED' =>
          'This account is disabled. Contact your administrator.',
        _ => 'Sign-in failed. Check your staff email and password.',
      });
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _idToken = data['idToken'] as String;
    uid = data['localId'] as String;
    _refreshToken = data['refreshToken'] as String;
    _expires = DateTime.now().add(const Duration(minutes: 50));
  }

  Future<String?> idToken() async {
    if (_idToken == null) return null;
    if (DateTime.now().isBefore(_expires)) return _idToken;
    final response = await _client
        .post(
          Uri.https('securetoken.googleapis.com', '/v1/token', {'key': apiKey}),
          body: {
            'grant_type': 'refresh_token',
            'refresh_token': _refreshToken!,
          },
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      signOut();
      throw const BackendException(
        'Your staff session expired. Please reconnect.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _idToken = data['id_token'] as String;
    _refreshToken = data['refresh_token'] as String;
    _expires = DateTime.now().add(const Duration(minutes: 50));
    return _idToken;
  }

  Future<void> sendPasswordReset(String email) async {
    final address = email.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(address) ||
        address.endsWith('.invalid')) {
      throw const BackendException(
        'Enter your registered email address. Center-issued ID-only accounts need administrator-assisted recovery.',
      );
    }
    final response = await _client
        .post(
          Uri.https(
            'identitytoolkit.googleapis.com',
            '/v1/accounts:sendOobCode',
            {'key': apiKey},
          ),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'requestType': 'PASSWORD_RESET', 'email': address}),
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body) as Map;
      if ((body['error'] as Map?)?['message'] != 'EMAIL_NOT_FOUND') {
        throw const BackendException(
          'Unable to request password recovery. Please try again later.',
        );
      }
    }
  }

  void signOut() {
    _idToken = null;
    _refreshToken = null;
    uid = null;
  }

  void close() {
    signOut();
    _client.close();
  }
}
