import 'backend_client.dart';

/// A center ID is presentation metadata. Internal document references stay stable.
String centerIdLabel(String internalId, String prefix) {
  if (internalId.startsWith(prefix)) {
    final number = int.tryParse(internalId.substring(prefix.length));
    if (number != null && number > 0 && number <= 999999) {
      return '$prefix${number.toString().padLeft(6, '0')}';
    }
  }
  return 'Not assigned';
}

String sequentialCenterId(String prefix, int number) {
  if (number < 1 || number > 999999) {
    throw const BackendException(
      'The center ID range is exhausted. Contact your administrator.',
    );
  }
  return '$prefix${number.toString().padLeft(6, '0')}';
}

const mobilePasswordHint = 'Password must be 8–16 characters.';
String? validateMobilePassword(String? password) {
  final length = (password ?? '').runes.length;
  if (length < 8) return 'Password must contain at least 8 characters.';
  if (length > 16) return 'Password must not exceed 16 characters.';
  return null;
}

String? confirmMobilePassword(String password, String confirmation) =>
    password == confirmation ? null : 'Passwords do not match.';
