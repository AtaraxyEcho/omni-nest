import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:omninest/core/network/api_client.dart';
import 'package:omninest/features/profile/domain/user_session.dart';

/// 当前用户 API 客户端。
class MeApi {
  const MeApi(this._client);

  final ApiClient _client;

  /// 上传头像，返回 presigned 下载 URL。
  Future<String> uploadAvatar(Uint8List bytes, String fileName) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
    });
    final response = await _client.dio.put<Map<String, dynamic>>(
      '/me/avatar',
      data: formData,
    );
    final data = response.data;
    if (data == null) throw Exception('头像上传失败');
    return data['data']?.toString() ?? '';
  }

  /// 修改当前用户密码。
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _client.dio.put<Map<String, dynamic>>(
      '/me/password',
      data: {'oldPassword': oldPassword, 'newPassword': newPassword},
    );
  }

  /// 获取当前用户的活跃会话列表。
  Future<List<UserSession>> getSessions() async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/me/sessions',
    );
    final data = response.data;
    if (data == null) return const [];
    final list = data['data'];
    if (list is! List) return const [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(UserSession.fromJson)
        .toList();
  }

  /// 撤销指定会话（主动登出其他设备）。
  Future<void> revokeSession(String sessionId) async {
    await _client.dio.delete<void>('/me/sessions/$sessionId');
  }
}
