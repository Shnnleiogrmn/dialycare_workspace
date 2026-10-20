import 'dart:convert';

import 'package:core_shared/core_shared.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'password recovery uses Firebase reset and keeps unknown accounts private',
    () async {
      var calls = 0;
      final identity = PasswordIdentity(
        'test-public-key',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/v1/accounts:sendOobCode');
          expect(jsonDecode(request.body), {
            'requestType': 'PASSWORD_RESET',
            'email': 'fictional@example.com',
          });
          return http.Response(
            jsonEncode({
              'error': {'message': 'EMAIL_NOT_FOUND'},
            }),
            400,
          );
        }),
      );
      await identity.sendPasswordReset('fictional@example.com');
      expect(calls, 1);
      expect(identity.uid, isNull);
      identity.close();
    },
  );

  test(
    'Auth UID is retained only after successful Firebase password sign-in',
    () async {
      var success = true;
      final identity = PasswordIdentity(
        'test-public-key',
        client: MockClient((request) async {
          expect(request.url.host, 'identitytoolkit.googleapis.com');
          expect(request.url.path, '/v1/accounts:signInWithPassword');
          if (!success) {
            return http.Response(
              jsonEncode({
                'error': {'message': 'INVALID_LOGIN_CREDENTIALS'},
              }),
              400,
            );
          }
          return http.Response(
            jsonEncode({
              'idToken': 'test-id-token',
              'refreshToken': 'test-refresh-token',
              'localId': 'test-staff-uid',
            }),
            200,
          );
        }),
      );
      await identity.signIn('fictional@example.invalid', 'test-only-password');
      expect(identity.uid, 'test-staff-uid');
      expect(await identity.idToken(), 'test-id-token');
      success = false;
      await expectLater(
        identity.signIn('fictional@example.invalid', 'incorrect'),
        throwsA(isA<BackendException>()),
      );
      expect(identity.uid, isNull);
      expect(await identity.idToken(), isNull);
      identity.close();
    },
  );

  test('provider setup failure differs from invalid credentials without exposing secrets', () async {
    final identity = PasswordIdentity(
      'test-public-key',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {'message': 'OPERATION_NOT_ALLOWED'},
          }),
          400,
        ),
      ),
    );
    await expectLater(
      identity.signIn('fictional@example.invalid', 'secret-not-for-error-text'),
      throwsA(
        isA<BackendException>().having(
          (e) => e.message,
          'message',
          contains('Email/Password'),
        ),
      ),
    );
    expect(identity.uid, isNull);
    identity.close();
  });
}
