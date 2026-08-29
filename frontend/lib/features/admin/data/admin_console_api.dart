import 'package:omninest/core/errors/app_exception.dart';
import 'package:omninest/core/network/api_client.dart';
import 'package:omninest/features/admin/domain/admin_console_summary.dart';

class AdminConsoleApi {
  const AdminConsoleApi(this.apiClient);

  final ApiClient apiClient;

  Future<AdminConsoleSummary> summary() async {
    final response = await apiClient.dio.get<Map<String, dynamic>>(
      '/admin/summary',
    );
    return parseSummaryResponse(response.data);
  }

  AdminConsoleSummary parseSummaryResponse(Map<String, dynamic>? body) {
    final data = parseData(body);
    return AdminConsoleSummary.fromJson(data);
  }

  Map<String, dynamic> parseData(Map<String, dynamic>? body) {
    final envelope = parseEnvelope(body);
    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw const AppException(
        code: 'INVALID_RESPONSE',
        message: '管理控制台响应格式不正确',
      );
    }
    return data;
  }

  Map<String, dynamic> parseEnvelope(Map<String, dynamic>? body) {
    if (body == null) {
      throw const AppException(
        code: 'EMPTY_RESPONSE',
        message: '服务端没有返回管理控制台结果',
      );
    }
    final code = body['code'];
    if (code != 200) {
      throw AppException(
        code: code?.toString() ?? 'ADMIN_CONSOLE_ERROR',
        message: body['message']?.toString() ?? '管理控制台加载失败',
      );
    }
    return body;
  }
}
