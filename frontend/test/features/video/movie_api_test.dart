import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/environment.dart';
import 'package:omninest/core/network/api_client.dart';
import 'package:omninest/features/video/data/movie_api.dart';

void main() {
  test('delete item sends delete request to video endpoint', () async {
    final adapter = _CapturingHttpClientAdapter();
    final api = MovieApi(_apiClient(adapter));

    await api.deleteItem('video-1');

    expect(adapter.lastMethod, 'DELETE');
    expect(adapter.lastPath, '/video/items/video-1');
  });

  test('subtitle loading truncates oversized responses to two MiB', () async {
    final adapter = _TextHttpClientAdapter(
      List<String>.filled(2 * 1024 * 1024 + 32, 'a').join(),
    );
    final api = MovieApi(_apiClient(adapter));

    final content = await api.loadSubtitle('http://minio/subtitle.vtt');

    expect(adapter.lastPath, 'http://minio/subtitle.vtt');
    expect(adapter.lastHeaders?['Range'], 'bytes=0-2097151');
    expect(content.length, 2 * 1024 * 1024);
  });
}

ApiClient _apiClient(HttpClientAdapter adapter) {
  return ApiClient(
    const AppEnvironment(
      apiBaseUrl: 'http://localhost:8080/api/v1',
      wsBaseUrl: 'ws://localhost:8080/ws',
    ),
    httpClientAdapter: adapter,
  );
}

class _CapturingHttpClientAdapter implements HttpClientAdapter {
  String? lastMethod;
  String? lastPath;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastMethod = options.method;
    lastPath = options.path;
    return ResponseBody.fromString(
      jsonEncode({'code': 200, 'message': 'success', 'data': {}}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _TextHttpClientAdapter implements HttpClientAdapter {
  _TextHttpClientAdapter(this.content);

  final String content;
  String? lastPath;
  Map<String, dynamic>? lastHeaders;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastHeaders = Map<String, dynamic>.from(options.headers);
    return ResponseBody.fromString(
      content,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
