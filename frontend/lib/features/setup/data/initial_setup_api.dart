import 'package:dio/dio.dart';
import 'package:omninest/core/errors/app_exception.dart';
import 'package:omninest/core/network/api_client.dart';
import 'package:omninest/features/setup/domain/initial_setup_status.dart';

class InitialSetupApi {
  const InitialSetupApi(this._client);

  final ApiClient _client;

  Future<InitialSetupStatus> status() async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/setup/status',
      options: _publicOptions,
    );
    final data = _parseEnvelope(response.data)['data'];
    if (data is! Map) {
      throw const AppException(
        code: 'SETUP_STATUS_INVALID',
        message: '安装状态响应格式不正确',
      );
    }
    return InitialSetupStatus.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> createSuperAdmin({
    required String setupToken,
    required String username,
    required String displayName,
    required String email,
    required String password,
    String instanceName = 'OmniNest',
    String defaultLocale = 'zh-CN',
    String defaultTimezone = 'Asia/Shanghai',
  }) async {
    final response = await _client.dio.post<Map<String, dynamic>>(
      '/setup/super-admin',
      data: {
        'username': username,
        'displayName': displayName,
        'email': email.isEmpty ? null : email,
        'password': password,
        'instanceName': instanceName,
        'defaultLocale': defaultLocale,
        'defaultTimezone': defaultTimezone,
      },
      options: _publicOptions.copyWith(headers: {'X-Setup-Token': setupToken}),
    );
    _parseEnvelope(response.data);
  }

  Map<String, dynamic> _parseEnvelope(Map<String, dynamic>? body) {
    final envelope = body ?? const <String, dynamic>{};
    final code = envelope['code'];
    if (code is num && code.toInt() >= 400) {
      throw AppException(
        code: code.toInt().toString(),
        message: envelope['message']?.toString() ?? '安装请求失败',
      );
    }
    return envelope;
  }

  static final _publicOptions = Options(
    extra: {ApiClient.skipAuthorizationKey: true},
  );
}
