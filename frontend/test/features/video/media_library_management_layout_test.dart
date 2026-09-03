import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_management.dart';
import 'package:omninest/features/video/presentation/widgets/movie_shell.dart';

void main() {
  testWidgets('media library uses source and workspace split on desktop', (
    tester,
  ) async {
    await _pumpLibrary(tester, size: const Size(1280, 900));

    expect(find.byKey(const Key('mediaLibraryDesktopSplit')), findsOneWidget);
    expect(find.byKey(const Key('mediaLibraryMobileStack')), findsNothing);
    expect(
      find.byKey(const Key('mediaLibrarySourceNavigator')),
      findsOneWidget,
    );
    expect(find.text('电影收藏'), findsNWidgets(2));

    await tester.tap(find.byKey(const Key('mediaLibrarySource-series')));
    await tester.pumpAndSettle();

    expect(find.text('家庭剧集'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('media library stacks controls without overflow on narrow view', (
    tester,
  ) async {
    await _pumpLibrary(tester, size: const Size(540, 1100), darkMode: true);

    expect(find.byKey(const Key('mediaLibraryMobileStack')), findsOneWidget);
    expect(find.byKey(const Key('mediaLibraryDesktopSplit')), findsNothing);
    expect(find.text('添加来源'), findsOneWidget);
    expect(find.text('发现更新'), findsOneWidget);
    expect(
      find.byKey(const Key('mediaLibraryUnavailablePanel')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('review workspace exposes candidate hierarchy inline', (
    tester,
  ) async {
    await _pumpLibrary(
      tester,
      size: const Size(1280, 900),
      reviewRun: _readyRun,
      reviewPage: _reviewPage,
      reviewChildNodeId: 'SERIES:1',
      reviewChildPage: _reviewChildPage,
    );

    final scanReviewTab = find.descendant(
      of: find.byType(SegmentedButton<int>),
      matching: find.text('扫描与审核'),
    );
    expect(scanReviewTab, findsOneWidget);
    await tester.tap(scanReviewTab);
    await tester.pumpAndSettle();

    // 媒体树为父子嵌套列表：根层节点直接可见，无右侧详情面板。
    expect(find.text('候选电影'), findsOneWidget);
    expect(find.text('示例剧集'), findsOneWidget);
    expect(find.textContaining('选择左侧候选'), findsNothing);

    // 文件夹节点原地展开懒加载子节点。
    await tester.tap(find.text('示例剧集'));
    await tester.pumpAndSettle();

    expect(find.text('示例剧集 第1集'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('access workspace switches to paged selected users', (
    tester,
  ) async {
    await _pumpLibrary(tester, size: const Size(1280, 900));

    await tester.tap(find.text('访问权限'));
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(RadioListTile<MediaLibraryVisibility>, '私人'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(RadioListTile<MediaLibraryVisibility>, '指定用户'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(RadioListTile<MediaLibraryVisibility>, '全部成员'),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(RadioListTile<MediaLibraryVisibility>, '指定用户'),
    );
    await tester.pumpAndSettle();

    expect(find.text('家庭成员'), findsOneWidget);
    expect(find.text('@member'), findsOneWidget);
    expect(find.text('保存访问权限'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('management navigation follows media library permission', (
    tester,
  ) async {
    Future<void> pumpSidebar(bool canManage) {
      return tester.pumpWidget(
        MaterialApp(
          theme: OmniNestTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('zh'),
          home: Scaffold(
            body: MovieSidebar(
              section: MovieSection.movies,
              canManage: canManage,
              closeOnSelect: false,
            ),
          ),
        ),
      );
    }

    await pumpSidebar(false);
    expect(find.text('影片管理'), findsNothing);
    expect(find.text('管理工具'), findsNothing);

    await pumpSidebar(true);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('影片管理'), findsOneWidget);
    expect(find.text('管理工具'), findsOneWidget);
  });
}

Future<void> _pumpLibrary(
  WidgetTester tester, {
  required Size size,
  bool darkMode = false,
  MediaScanRun? reviewRun,
  MediaPage<MediaScanTreeNode>? reviewPage,
  String? reviewChildNodeId,
  MediaPage<MediaScanTreeNode>? reviewChildPage,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        videoStorageLocationsProvider.overrideWith(
          (ref) async => const [_storageLocation],
        ),
        videoLibrarySourcesProvider.overrideWith(
          (ref) async => _librarySources,
        ),
        mediaLibraryAccessProvider('movie').overrideWith(
          (ref) async => const MediaLibraryAccessSettings(
            librarySourceId: 'movie',
            visibility: MediaLibraryVisibility.private,
            selectedUserIds: <String>{},
            version: 0,
          ),
        ),
        mediaLibraryAccessUsersProvider((query: '', page: 0)).overrideWith(
          (ref) async => const MediaPage<MediaLibraryUserCandidate>(
            items: [
              MediaLibraryUserCandidate(
                id: 'member-id',
                username: 'member',
                displayName: '家庭成员',
                status: 'ACTIVE',
              ),
            ],
            page: 0,
            size: 50,
            totalElements: 1,
            totalPages: 1,
          ),
        ),
        latestMediaScanRunProvider(
          'movie',
        ).overrideWith((ref) => Stream.value(reviewRun)),
        latestMediaScanRunProvider(
          'series',
        ).overrideWith((ref) => Stream.value(null)),
        unavailableLocalMediaProvider.overrideWith(
          (ref) async => const MediaPage<MediaUnavailableItem>(
            items: [],
            page: 0,
            size: 50,
            totalElements: 0,
            totalPages: 0,
          ),
        ),
        if (reviewRun != null && reviewPage != null)
          mediaScanTreeProvider((
            runId: reviewRun.id,
            parentNodeId: null,
            page: 0,
          )).overrideWith((ref) async => reviewPage),
        if (reviewRun != null &&
            reviewChildNodeId != null &&
            reviewChildPage != null)
          mediaScanTreeProvider((
            runId: reviewRun.id,
            parentNodeId: reviewChildNodeId,
            page: 0,
          )).overrideWith((ref) async => reviewChildPage),
      ],
      child: MaterialApp(
        theme: darkMode ? OmniNestTheme.dark() : OmniNestTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: const Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: LocalLibrarySourcesPanel(),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _storageLocation = VideoStorageLocation(
  id: 'storage',
  name: '家庭媒体盘',
  providerType: 'LOCAL_FILESYSTEM',
  mountKey: 'media',
  relativeRoot: '.',
  scopeType: 'SHARED',
  enabled: true,
  healthStatus: 'AVAILABLE',
);

const _librarySources = [
  VideoLibrarySource(
    id: 'movie',
    name: '电影收藏',
    storageLocationId: 'storage',
    relativeRoot: 'Movie',
    libraryType: VideoLibraryType.movie,
    importPolicy: 'MANUAL_REVIEW',
    visibility: MediaLibraryVisibility.private,
    enabled: true,
    scanStatus: 'READY',
    healthStatus: 'AVAILABLE',
    lastScannedCount: 24,
    lastCreatedCount: 0,
    lastCandidateCount: 3,
    lastMissingCount: 0,
    version: 0,
  ),
  VideoLibrarySource(
    id: 'series',
    name: '家庭剧集',
    storageLocationId: 'storage',
    relativeRoot: 'TV Series',
    libraryType: VideoLibraryType.tvSeries,
    importPolicy: 'MANUAL_REVIEW',
    visibility: MediaLibraryVisibility.allMembers,
    enabled: true,
    scanStatus: 'COMPLETED',
    healthStatus: 'AVAILABLE',
    lastScannedCount: 138,
    lastCreatedCount: 120,
    lastCandidateCount: 0,
    lastMissingCount: 1,
    version: 0,
  ),
];

const _readyRun = MediaScanRun(
  id: 'run-ready',
  librarySourceId: 'movie',
  generation: 2,
  selectionRevision: 4,
  status: 'READY',
  phase: 'DISCOVERY',
  discoveredCount: 26,
  candidateCount: 24,
  existingCount: 2,
  conflictCount: 1,
  unmatchedCount: 0,
  missingCount: 0,
  selectedCount: 3,
  appliedCount: 0,
  failedCount: 0,
);

const _reviewChildPage = MediaPage<MediaScanTreeNode>(
  items: [
    MediaScanTreeNode(
      nodeId: 'EPISODE:1',
      nodeType: 'FILE',
      title: '示例剧集 第1集',
      hasChildren: false,
      childCount: 0,
      candidateCount: 1,
      selectedCount: 1,
      issueCount: 0,
      selectionState: 'ALL',
      matchStatus: 'NEW',
    ),
  ],
  page: 0,
  size: 100,
  totalElements: 1,
  totalPages: 1,
);

const _reviewPage = MediaPage<MediaScanTreeNode>(
  items: [
    MediaScanTreeNode(
      nodeId: 'MOVIE:1',
      nodeType: 'MOVIE',
      title: '候选电影',
      subtitle: 'Movie/Candidate.2026.mkv',
      hasChildren: false,
      childCount: 0,
      candidateCount: 1,
      selectedCount: 1,
      issueCount: 0,
      selectionState: 'ALL',
      matchStatus: 'NEW',
    ),
    MediaScanTreeNode(
      nodeId: 'SERIES:1',
      nodeType: 'SERIES',
      title: '示例剧集',
      hasChildren: true,
      childCount: 2,
      candidateCount: 23,
      selectedCount: 2,
      issueCount: 1,
      selectionState: 'PARTIAL',
      matchStatus: 'AMBIGUOUS',
    ),
  ],
  page: 0,
  size: 100,
  totalElements: 2,
  totalPages: 1,
);
