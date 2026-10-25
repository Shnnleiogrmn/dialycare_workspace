import 'backend_client.dart';

/// A center ID is presentation metadata. Internal document references stay stable.
String centerIdLabel(String internalId, String prefix) {
  if (prefix == 'DC-' && patientIdYear(internalId) != null) return internalId;
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

/// Registration-year business identifier; internal references need not use it.
String yearlyPatientId(int year, int number) {
  if (year < 1000 || year > 9999 || number < 1 || number > 999) {
    throw const BackendException(
      'The Patient ID range for this registration year is exhausted. Contact your administrator.',
    );
  }
  return 'DP-$year-${number.toString().padLeft(3, '0')}';
}

int? patientIdYear(String id) {
  final match = RegExp(r'^DP-([1-9][0-9]{3})-([0-9]{3,4})$').firstMatch(id);
  if (match == null || int.parse(match[2]!) == 0) return null;
  return int.parse(match[1]!);
}

int? patientIdSequence(String id) =>
    patientIdYear(id) == null ? null : int.parse(id.split('-').last);

/// Compatibility is bounded to the explicit 2026 migration and the same number.
/// Internal record references and Auth UIDs are never changed by this mapping.
List<String> patientLoginIds(String role, String input) {
  final id = input.trim().toUpperCase();
  if (role != 'patient') return [id];
  final legacy = RegExp(r'^DC-([0-9]{1,6})$').firstMatch(id);
  final year = patientIdYear(id) ?? (legacy == null ? null : 2026);
  final number = legacy == null
      ? patientIdSequence(id)
      : int.tryParse(legacy[1]!);
  if (year == null || number == null || number < 1 || number > 999) return [id];
  return <String>{
    id,
    yearlyPatientId(year, number),
    'DP-$year-${number.toString().padLeft(4, '0')}',
    if (year == 2026) sequentialCenterId('DC-', number),
    if (year == 2026) 'DC-${number.toString().padLeft(3, '0')}',
  }.toList();
}
