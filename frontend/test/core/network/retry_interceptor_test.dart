import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/core/network/retry_interceptor.dart';

void main() {
  late Dio dio;
  late RetryInterceptor interceptor;

  setUp(() {
    interceptor = RetryInterceptor(maxRetries: 2);
    dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
    dio.interceptors.add(interceptor);
  });

  RequestOptions getOptions({String method = 'GET'}) {
    return RequestOptions(
      path: '/test',
      baseUrl: 'https://example.com',
      method: method,
    );
  }

  DioException buildException({
    required DioExceptionType type,
    int? statusCode,
    String method = 'GET',
    Map<String, dynamic>? headers,
  }) {
    final options = getOptions(method: method);
    options.headers.addAll(headers ?? const <String, dynamic>{});
    Response<dynamic>? response;
    if (statusCode != null) {
      response = Response(statusCode: statusCode, requestOptions: options);
    }
    return DioException(
      type: type,
      requestOptions: options,
      response: response,
    );
  }

  group('RetryInterceptor', () {
    test('does not retry on 400 Bad Request', () async {
      final handler = _TestErrorHandler();
      final exception = buildException(
        type: DioExceptionType.badResponse,
        statusCode: 400,
      );

      await interceptor.onError(exception, handler);

      expect(handler.nextCount, 1);
      expect(handler.resolveCount, 0);
      expect(handler.lastError?.response?.statusCode, 400);
    });

    test('retries on 503 Service Unavailable up to maxRetries', () async {
      final handler = _TestErrorHandler();
      final exception = buildException(
        type: DioExceptionType.badResponse,
        statusCode: 503,
      );

      // 第一次调用：应该重试（retryCount 从 0 开始）
      await interceptor.onError(exception, handler);
      expect(handler.resolveCount + handler.nextCount, 1);

      // 模拟重试失败后再次调用拦截器
      final handler2 = _TestErrorHandler();
      exception.requestOptions.extra['retryCount'] = 1;
      await interceptor.onError(exception, handler2);
      // retryCount=1 < maxRetries=2，应该继续重试
      expect(handler2.resolveCount + handler2.nextCount, 1);

      // 达到 maxRetries 后不再重试
      final handler3 = _TestErrorHandler();
      exception.requestOptions.extra['retryCount'] = 2;
      await interceptor.onError(exception, handler3);
      expect(handler3.nextCount, 1);
      expect(handler3.resolveCount, 0);
    });

    test('retries on connection timeout', () async {
      final handler = _TestErrorHandler();
      final exception = buildException(
        type: DioExceptionType.connectionTimeout,
      );

      await interceptor.onError(exception, handler);

      // 连接超时应该触发重试，要么 resolve 要么 next
      expect(handler.resolveCount + handler.nextCount, 1);
    });

    test('does not exceed maxRetries', () async {
      final handler = _TestErrorHandler();
      final exception = buildException(
        type: DioExceptionType.connectionTimeout,
      );

      // 设置 retryCount 达到最大值
      exception.requestOptions.extra['retryCount'] = 2;

      await interceptor.onError(exception, handler);

      expect(handler.nextCount, 1);
      expect(handler.resolveCount, 0);
      expect(handler.lastError?.type, DioExceptionType.connectionTimeout);
    });

    test('does not retry POST on 500 (only on connection error)', () async {
      final handler = _TestErrorHandler();
      final exception = buildException(
        type: DioExceptionType.badResponse,
        statusCode: 500,
        method: 'POST',
      );

      await interceptor.onError(exception, handler);

      expect(handler.nextCount, 1);
      expect(handler.resolveCount, 0);
    });

    test(
      'does not retry POST on connection error without idempotency key',
      () async {
        final handler = _TestErrorHandler();
        final exception = buildException(
          type: DioExceptionType.connectionError,
          method: 'POST',
        );

        await interceptor.onError(exception, handler);

        expect(handler.nextCount, 1);
        expect(handler.resolveCount, 0);
        expect(exception.requestOptions.extra['retryCount'], isNull);
      },
    );

    test('retries POST with idempotency key on connection error', () async {
      final handler = _TestErrorHandler();
      final exception = buildException(
        type: DioExceptionType.connectionError,
        method: 'POST',
        headers: {'Idempotency-Key': 'request-1'},
      );

      await interceptor.onError(exception, handler);

      expect(handler.resolveCount + handler.nextCount, 1);
      expect(exception.requestOptions.extra['retryCount'], 1);
    });

    test('retries on 408 Request Timeout for GET', () async {
      final handler = _TestErrorHandler();
      final exception = buildException(
        type: DioExceptionType.badResponse,
        statusCode: 408,
      );

      await interceptor.onError(exception, handler);

      expect(handler.resolveCount + handler.nextCount, 1);
    });

    test('retries on receive timeout', () async {
      final handler = _TestErrorHandler();
      final exception = buildException(type: DioExceptionType.receiveTimeout);

      await interceptor.onError(exception, handler);

      expect(handler.resolveCount + handler.nextCount, 1);
    });

    test('does not retry POST on 429', () async {
      final handler = _TestErrorHandler();
      final exception = buildException(
        type: DioExceptionType.badResponse,
        statusCode: 429,
        method: 'POST',
      );

      await interceptor.onError(exception, handler);

      expect(handler.nextCount, 1);
      expect(handler.resolveCount, 0);
    });

    test('stores retry count in requestOptions.extra', () async {
      final handler = _TestErrorHandler();
      final exception = buildException(
        type: DioExceptionType.connectionTimeout,
      );

      expect(exception.requestOptions.extra['retryCount'], isNull);

      await interceptor.onError(exception, handler);

      expect(exception.requestOptions.extra['retryCount'], 1);
    });
  });
}

/// 用于测试的 ErrorInterceptorHandler 替身。
class _TestErrorHandler extends ErrorInterceptorHandler {
  int nextCount = 0;
  int resolveCount = 0;
  DioException? lastError;

  @override
  void next(DioException err) {
    nextCount++;
    lastError = err;
  }

  @override
  void resolve(Response<dynamic> response) {
    resolveCount++;
  }
}
