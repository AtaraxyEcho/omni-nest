import 'package:omninest/core/errors/app_exception.dart';
import 'package:omninest/core/network/api_client.dart';
import 'package:omninest/features/admin/domain/admin_user.dart';

class AdminUserApi {
  const AdminUserApi(this.apiClient);

  final ApiClient apiClient;

  Future<({List<AdminUser> items, int total})> listUsers({
    int page = 0,
    int size = 50,
  }) async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/admin/users',
      queryParameters: {'page': page, 'size': size},
    );
    return parseUserPageResponse(response.data);
  }

  Future<AdminUser> createUser(AdminCreateUserInput input) async {
    final response = await apiClient.dio.post<Map<String, dynamic>>(
      '/admin/users',
      data: input.toJson(),
    );
    return parseUserResponse(response.data);
  }

  Future<AdminUser> updateUserStatus(String userId, String status) async {
    final response = await apiClient.dio.patch<Map<String, dynamic>>(
      '/admin/users/$userId/status',
      data: {'status': status},
    );
    return parseUserResponse(response.data);
  }

  Future<AdminUser> updateUserRoles(String userId, Set<String> roles) async {
    final response = await apiClient.dio.patch<Map<String, dynamic>>(
      '/admin/users/$userId/roles',
      data: {'roles': roles.toList()},
    );
    return parseUserResponse(response.data);
  }

  Future<AdminUser> updateUserQuota(String userId, int quotaBytes) async {
    final response = await apiClient.dio.patch<Map<String, dynamic>>(
      '/admin/users/$userId/quota',
      data: {'quotaBytes': quotaBytes},
    );
    return parseUserResponse(response.data);
  }

  Future<int> batchUpdateQuota(List<String> userIds, int quotaBytes) async {
    final response = await apiClient.dio.patch<Map<String, dynamic>>(
      '/admin/users/quota/batch',
      data: {'userIds': userIds, 'quotaBytes': quotaBytes},
    );
    final envelope = parseEnvelope(response.data);
    final data = envelope['data'];
    if (data is int) return data;
    if (data is num) return data.toInt();
    return int.tryParse(data?.toString() ?? '') ?? 0;
  }

  ({List<AdminUser> items, int total}) parseUserPageResponse(
    Map<String, dynamic>? body,
  ) {
    final data = parseData(body);
    final items = data['items'];
    if (items is! List) {
      throw const AppException(code: 'INVALID_RESPONSE', message: '用户列表格式不正确');
    }
    final users =
        items
            .whereType<Map<String, dynamic>>()
            .map(AdminUser.fromJson)
            .toList();
    final total = (data['totalElements'] as num?)?.toInt() ?? users.length;
    return (items: users, total: total);
  }

  AdminUser parseUserResponse(Map<String, dynamic>? body) {
    return AdminUser.fromJson(parseData(body));
  }

  Map<String, dynamic> parseData(Map<String, dynamic>? body) {
    final envelope = parseEnvelope(body);
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const AppException(code: 'INVALID_RESPONSE', message: '用户响应格式不正确');
    }
    return data;
  }

  Map<String, dynamic> parseEnvelope(Map<String, dynamic>? body) {
    if (body == null) {
      throw const AppException(code: 'EMPTY_RESPONSE', message: '服务端没有返回用户结果');
    }
    final code = body['code'];
    if (code != 200) {
      throw AppException(
        code: code?.toString() ?? 'ADMIN_USER_ERROR',
        message: body['message']?.toString() ?? '用户操作失败',
      );
    }
    return body;
  }
}
