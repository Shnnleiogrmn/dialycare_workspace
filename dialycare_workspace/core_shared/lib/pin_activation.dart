import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'backend_client.dart';

/// Prototype verification lookup, separate from clinical records and passwords.
/// A six-digit PIN is low entropy: production requires trusted rate limiting.
String pinInvitationId(String role, String id, String pin) {
  accountEmail(role, id); // Validate the center-issued identifier.
  if (!RegExp(r'^\d{6}$').hasMatch(pin.trim())) {
    throw const BackendException(
      'Enter the six-digit Temporary PIN from your dialysis center.',
    );
  }
  return sha256
      .convert(
        utf8.encode(
          'dialycare-pin-v1\n$role\n${id.trim().toLowerCase()}\n${pin.trim()}',
        ),
      )
      .toString();
}

String generateTemporaryPin() =>
    (100000 + Random.secure().nextInt(900000)).toString();
