import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/environment.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/core/network/api_client.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/data/movie_api.dart';
import 'package:omninest/features/video/presentation/widgets/movie_management.dart';

void main() {
  testWidgets('影片管理列表按剧聚合并显示连续序号', (tester) async {
    final container = _container();
    await _pumpSection(tester, container);

    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('家庭剧集'), findsOneWidget);
    expect(find.textContaining('3 集'), findsOneWidget);
    expect(find.text('独立电影A'), findsOneWidget);
    expect(find.text('独立电影B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('状态筛选 chips 过滤影片列表', (tester) async {
    final container = _container();
    await _pumpSection(tester, container);

    await tester.tap(find.widgetWithText(ChoiceChip, '待刮削'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('独立电影B'), findsOneWidget);
    expect(find.text('独立电影A'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('任务进度弹窗展示任务类型与进度', (tester) async {
    final container = _container();
    await _pumpSection(tester, container);

    // 弹窗内持有 2 秒周期刷新 Timer，避免 pumpAndSettle 永不静止。
    await tester.tap(find.text('任务进度'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('任务进度'), findsWidgets);
    expect(find.textContaining('视频转码 · 执行中'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.textContaining('元数据抓取 · 排队中'), findsOneWidget);
    expect(find.text('0%'), findsOneWidget);

    await tester.tap(find.text('关闭'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });
}

ProviderContainer _container() {
  return ProviderContainer.test(
    overrides: [
      movieApiProvider.overrideWithValue(
        MovieApi(
          ApiClient(
            const AppEnvironment(
              apiBaseUrl: 'http://localhost:8080/api/v1',
              wsBaseUrl: 'ws://localhost:8080/ws',
            ),
            httpClientAdapter: _MovieAdminApiAdapter(),
          ),
        ),
      ),
    ],
  );
}

Future<void> _pumpSection(
  WidgetTester tester,
  ProviderContainer container,
) async {
  // testWidgets 运行在 FakeAsync 区：dio 异步链需在 runAsync 中真实推进。
  await tester.runAsync(() async {
    await container.read(movieCenterControllerProvider.future);
    container
        .read(movieCenterControllerProvider.notifier)
        .selectSection(MovieSection.management);
    await Future<void>.delayed(const Duration(milliseconds: 50));
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: OmniNestTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const Scaffold(body: MovieAdminSection()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

class _MovieAdminApiAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final data = switch (options.path) {
      '/video/dashboard' => _dashboard(),
      '/video/library/page' => _libraryPage(),
      '/video/tasks' => _tasks(),
      _ => throw StateError('未处理的测试请求: ${options.path}'),
    };
    return ResponseBody.fromString(
      jsonEncode({'code': 200, 'message': 'success', 'data': data}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  Map<String, Object> _dashboard() {
    return {
      'stats': {
        'movieCount': 3,
        'episodeCount': 3,
        'seriesCount': 1,
        'scrapeFailedCount': 0,
      },
      'recentlyAdded': <Object>[],
      'continueWatching': <Object>[],
      'series': <Object>[],
    };
  }

  Map<String, Object> _libraryPage() {
    return {
      'items': <Object>[
        _movie('movie-a', '独立电影A', 'MATCHED'),
        _movie('movie-b', '独立电影B', 'PENDING'),
        _movie('movie-c', '独立电影C', 'MATCHED'),
        _episode('ep-1', '家庭剧集', 'series-1'),
        _episode('ep-2', '家庭剧集', 'series-1'),
        _episode('ep-3', '家庭剧集', 'series-1'),
      ],
      'page': 0,
      'size': 36,
      'totalElements': 6,
      'totalPages': 1,
    };
  }

  Map<String, Object> _movie(String id, String title, String metadataStatus) {
    return {
      'id': id,
      'fileNodeId': 'file-$id',
      'mediaType': 'MOVIE',
      'title': title,
      'metadataStatus': metadataStatus,
      'nfoStatus': 'EXPORTED',
      'availabilityStatus': 'AVAILABLE',
    };
  }

  Map<String, Object> _episode(String id, String title, String seriesId) {
    return {
      'id': id,
      'fileNodeId': 'file-$id',
      'mediaType': 'EPISODE',
      'title': title,
      'metadataStatus': 'MATCHED',
      'nfoStatus': 'EXPORTED',
      'seriesId': seriesId,
      'availabilityStatus': 'AVAILABLE',
    };
  }

  List<Object> _tasks() {
    return [
      {
        'id': 'task-1',
        'taskType': 'VIDEO_TRANSCODE',
        'status': 'RUNNING',
        'progress': 62,
      },
      {
        'id': 'task-2',
        'taskType': 'MEDIA_SCRAPE',
        'status': 'QUEUED',
        'progress': 0,
      },
    ];
  }

  @override
  void close({bool force = false}) {}
}
