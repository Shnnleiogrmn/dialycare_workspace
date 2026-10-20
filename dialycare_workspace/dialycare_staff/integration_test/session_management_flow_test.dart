import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/session_management_test.dart' show sessionManagementUiFlow;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Windows grouped sessions, confirmations and all status states',
    sessionManagementUiFlow,
  );
}
