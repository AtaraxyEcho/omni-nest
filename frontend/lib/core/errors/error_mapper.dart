import 'package:omninest/core/errors/app_exception.dart';

AppException mapBackendError(Map<String, Object?> payload) {
  return AppException(
    code: payload['code']?.toString() ?? 'UNKNOWN',
    message: payload['message']?.toString() ?? '请求失败',
    details: payload,
  );
}
