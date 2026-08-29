import 'package:dio/dio.dart';
import 'package:omninest/core/errors/app_exception.dart';

class UserFacingError {
  const UserFacingError({
    required this.title,
    required this.message,
    this.code,
  });

  final String title;
  final String message;
  final String? code;

  String get displayMessage =>
      code == null || code!.isEmpty ? message : '$message（$code）';
}

UserFacingError describeUserFacingError(Object error) {
  if (error is AppException) {
    return UserFacingError(
      title: '操作失败',
      message: error.message,
      code: error.code,
    );
  }
  if (error is DioException) {
    return _describeDioException(error);
  }
  return UserFacingError(
    title: '操作失败',
    message: error.toString().isEmpty ? '请求失败，请稍后重试' : error.toString(),
  );
}

UserFacingError _describeDioException(DioException error) {
  final backend = _backendError(error.response?.data);
  if (backend != null) {
    return backend;
  }
  final code = error.response?.statusCode?.toString();
  if (error.response?.statusCode == 503) {
    return const UserFacingError(
      title: '操作失败',
      message: '服务暂时不可用，请稍后重试；文件仍处于安全隔离状态',
      code: 'SERVICE_UNAVAILABLE',
    );
  }
  return switch (error.type) {
    DioExceptionType.connectionError => const UserFacingError(
      title: '操作失败',
      message: '无法连接后端服务，请确认服务已启动或网络可用',
      code: 'NETWORK_ERROR',
    ),
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => const UserFacingError(
      title: '操作失败',
      message: '请求超时，请稍后重试',
      code: 'REQUEST_TIMEOUT',
    ),
    DioExceptionType.cancel => const UserFacingError(
      title: '操作失败',
      message: '请求已取消',
      code: 'REQUEST_CANCELLED',
    ),
    DioExceptionType.badCertificate => const UserFacingError(
      title: '操作失败',
      message: '后端证书校验失败，请检查服务配置',
      code: 'BAD_CERTIFICATE',
    ),
    DioExceptionType.badResponse => UserFacingError(
      title: '操作失败',
      message: code == null ? '服务端返回错误，请稍后重试' : '服务端返回 $code 错误',
      code: code,
    ),
    DioExceptionType.unknown => UserFacingError(
      title: '操作失败',
      message:
          error.message?.isNotEmpty == true ? error.message! : '请求失败，请稍后重试',
      code: code,
    ),
  };
}

UserFacingError? _backendError(Object? data) {
  if (data is Map<String, dynamic>) {
    final message = data['message']?.toString();
    if (message == null || message.isEmpty) {
      return null;
    }
    return UserFacingError(
      title: '操作失败',
      message: message,
      code: data['code']?.toString(),
    );
  }
  if (data is Map) {
    final message = data['message']?.toString();
    if (message == null || message.isEmpty) {
      return null;
    }
    return UserFacingError(
      title: '操作失败',
      message: message,
      code: data['code']?.toString(),
    );
  }
  return null;
}
