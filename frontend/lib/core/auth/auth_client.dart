import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:omninest/core/auth/auth_models.dart';
import 'package:omninest/core/errors/app_exception.dart';
import 'package:omninest/core/network/api_client.dart';

class AuthClient {
  AuthClient(Object client, {String? clientPlatform})
    : _dio = client is ApiClient ? client.dio : client as Dio,
      _clientPlatform = clientPlatform ?? _defaultPlatform();

  final Dio _dio;
  final String _clientPlatform;

  /// 检测当前平台标识，用于后端同平台会话互斥。
  /// Web 使用 "web"，原生端使用具体平台名（android/ios/windows/macos/linux）。
  static String _defaultPlatform() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      _ => 'native',
    };
  }

  Future<AuthTokenResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'username': username, 'password': password},
      options: _credentialOptions(),
    );

    return parseAuthResponse(response.data);
  }

  Future<AuthTokenResponse> refresh({String? refreshToken}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data:
          refreshToken == null || refreshToken.isEmpty
              ? null
              : {'refreshToken': refreshToken},
      options: _credentialOptions(),
    );

    return parseAuthResponse(response.data);
  }

  AuthTokenResponse parseAuthResponse(Map<String, dynamic>? body) {
    if (body == null) {
      throw const AppException(code: 'EMPTY_RESPONSE', message: '服务端没有返回认证结果');
    }

    final code = body['code'];
    final message = body['message']?.toString() ?? '认证失败';
    if (code != 200) {
      throw AppException(
        code: code?.toString() ?? 'AUTH_ERROR',
        message: message,
      );
    }

    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw const AppException(code: 'INVALID_RESPONSE', message: '认证结果格式不正确');
    }

    return AuthTokenResponse.fromJson(data);
  }

  /// 修改当前用户密码。
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.put<Map<String, dynamic>>(
      '/me/password',
      data: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
  }

  Options _credentialOptions() {
    return Options(
      headers: {'X-Client-Platform': _clientPlatform},
      extra: {'withCredentials': true},
    );
  }
}
