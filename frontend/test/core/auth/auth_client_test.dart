import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/environment.dart';
import 'package:omninest/core/auth/auth_client.dart';
import 'package:omninest/core/errors/app_exception.dart';
import 'package:omninest/core/network/api_client.dart';

void main() {
  late AuthClient authClient;

  setUp(() {
    authClient = AuthClient(
      ApiClient(
        const AppEnvironment(
          apiBaseUrl: 'http://localhost:8080/api/v1',
          wsBaseUrl: 'ws://localhost:8080/ws',
        ),
      ),
    );
  });

  test('parses successful login response', () {
    final result = authClient.parseAuthResponse({
      'code': 200,
      'message': 'success',
      'data': {
        'tokenType': 'Bearer',
        'accessToken': 'token-value',
        'expiresAt': '2026-05-19T12:00:00Z',
        'refreshToken': 'refresh-token-value',
        'refreshExpiresAt': '2026-06-18T12:00:00Z',
        'user': {
          'id': '27f7d398-6f3a-4d2b-89bb-9483af60f84a',
          'username': 'root',
          'displayName': 'root',
          'email': 'root@example.com',
          'role': 'USER',
        },
      },
    });

    expect(result.tokenType, 'Bearer');
    expect(result.accessToken, 'token-value');
    expect(result.refreshToken, 'refresh-token-value');
    expect(
      result.refreshExpiresAt,
      DateTime.parse('2026-06-18T12:00:00Z').toLocal(),
    );
    expect(result.user.username, 'root');
  });

  test('throws app exception when login response is not success', () {
    expect(
      () => authClient.parseAuthResponse({
        'code': 401,
        'message': '用户名或密码错误',
        'data': null,
      }),
      throwsA(isA<AppException>()),
    );
  });
}
