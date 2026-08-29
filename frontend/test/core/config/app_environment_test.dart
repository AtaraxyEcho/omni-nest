import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/environment.dart';

void main() {
  test('environment has local defaults', () {
    final environment = AppEnvironment.fromDefines();

    expect(environment.apiBaseUrl, contains('/api/v1'));
    expect(environment.wsBaseUrl, startsWith('ws://'));
  });
}
