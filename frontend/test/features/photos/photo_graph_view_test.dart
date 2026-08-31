import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/photos/application/photo_center_models.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/domain/photo_face_cluster.dart';
import 'package:omninest/features/photos/domain/photo_group.dart';
import 'package:omninest/features/photos/domain/photo_relation.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_graph_models.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_graph_view.dart';

void main() {
  test('buildPhotoGraph 构建带类型前缀的节点并解析展示名', () {
    final relation = _relation(
      nodes: [
        const PhotoRelationNode(
          type: PhotoRelationNodeType.album,
          key: 'album-1',
          label: 'Japan',
          weight: 10,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.time,
          key: '2026-08',
          label: null,
          weight: 6,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.person,
          key: 'person-1',
          label: null,
          weight: 3,
        ),
      ],
      edges: [
        const PhotoRelationEdge(
          sourceType: PhotoRelationNodeType.album,
          sourceKey: 'album-1',
          targetType: PhotoRelationNodeType.time,
          targetKey: '2026-08',
          weight: 4,
        ),
      ],
    );

    final graph = buildPhotoGraph(
      relation: relation,
      kinds: {...PhotoRelationNodeType.values},
      query: '',
    );

    expect(graph.nodes.map((node) => node.id), [
      'ALBUM:album-1',
      'TIME:2026-08',
      'PERSON:person-1',
    ]);
    expect(graph.nodes[0].label, 'Japan');
    expect(graph.nodes[1].label, '2026-08');
    expect(graph.edges.single.sourceId, 'ALBUM:album-1');
    expect(graph.edges.single.targetId, 'TIME:2026-08');
    expect(graph.truncated, isFalse);
  });

  test('buildPhotoGraph 从当前列表富化相册与人物封面', () {
    final relation = _relation(
      nodes: [
        const PhotoRelationNode(
          type: PhotoRelationNodeType.album,
          key: 'album-1',
          label: 'Japan',
          weight: 1,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.person,
          key: 'person-1',
          label: 'Alice',
          weight: 2,
        ),
      ],
      edges: [],
    );
    final state = PhotoCenterState.empty().copyWith(
      albums: [
        PhotoAlbum(
          id: 'album-1',
          name: 'Japan',
          description: '',
          photoCount: 1,
          createdAt: null,
          updatedAt: null,
          coverUrl: 'https://example.test/album.jpg',
        ),
      ],
      faceClusters: [
        const PhotoFaceCluster(
          id: 'person-1',
          name: 'Alice',
          faceCount: 2,
          coverPhotoUrl: 'https://example.test/alice.jpg',
        ),
      ],
    );

    final graph = buildPhotoGraph(
      relation: relation,
      kinds: {...PhotoRelationNodeType.values},
      query: '',
      albums: state.albums,
      faceClusters: state.faceClusters,
    );

    expect(
      graph.nodes.firstWhere((n) => n.id == 'ALBUM:album-1').coverUrl,
      'https://example.test/album.jpg',
    );
    expect(
      graph.nodes.firstWhere((n) => n.id == 'PERSON:person-1').coverUrl,
      'https://example.test/alice.jpg',
    );
  });

  test('buildPhotoGraph 按类型筛选节点并丢弃端点缺失的边', () {
    final relation = _relation(
      nodes: [
        const PhotoRelationNode(
          type: PhotoRelationNodeType.album,
          key: 'album-1',
          label: 'Japan',
          weight: 10,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.time,
          key: '2026-08',
          label: null,
          weight: 6,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.person,
          key: 'person-1',
          label: 'Alice',
          weight: 3,
        ),
      ],
      edges: [
        const PhotoRelationEdge(
          sourceType: PhotoRelationNodeType.album,
          sourceKey: 'album-1',
          targetType: PhotoRelationNodeType.time,
          targetKey: '2026-08',
          weight: 4,
        ),
        const PhotoRelationEdge(
          sourceType: PhotoRelationNodeType.album,
          sourceKey: 'album-1',
          targetType: PhotoRelationNodeType.person,
          targetKey: 'person-1',
          weight: 2,
        ),
      ],
    );

    final graph = buildPhotoGraph(
      relation: relation,
      kinds: {PhotoRelationNodeType.album, PhotoRelationNodeType.time},
      query: '',
    );

    expect(graph.nodes.map((node) => node.type), [
      PhotoRelationNodeType.album,
      PhotoRelationNodeType.time,
    ]);
    expect(graph.edges, hasLength(1));
  });

  test('buildPhotoGraph 搜索过滤节点标签', () {
    final relation = _relation(
      nodes: [
        const PhotoRelationNode(
          type: PhotoRelationNodeType.album,
          key: 'album-1',
          label: 'Japan Trip',
          weight: 5,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.location,
          key: '杭州',
          label: null,
          weight: 2,
        ),
      ],
      edges: [],
    );

    final graph = buildPhotoGraph(
      relation: relation,
      kinds: {...PhotoRelationNodeType.values},
      query: 'japan',
    );

    expect(graph.nodes.single.id, 'ALBUM:album-1');
  });

  test('buildPhotoGraph 超出节点上限时按权重截断并标记', () {
    final relation = _relation(
      nodes: [
        for (var index = 0; index < maxPhotoGraphNodes + 10; index++)
          PhotoRelationNode(
            type: PhotoRelationNodeType.album,
            key: 'album-$index',
            label: 'album-$index',
            weight: 100 - index,
          ),
      ],
      edges: [],
    );

    final graph = buildPhotoGraph(
      relation: relation,
      kinds: {...PhotoRelationNodeType.values},
      query: '',
    );

    expect(graph.nodes, hasLength(maxPhotoGraphNodes));
    expect(graph.truncated, isTrue);
    expect(graph.nodes.first.weight, 100);
  });

  test('PhotoGraphLayout 确定性初始化且 settle 后收敛', () {
    final nodes = [
      for (var index = 0; index < 6; index++)
        PhotoGraphNode(
          id: 'node-$index',
          type: PhotoRelationNodeType.album,
          key: 'node-$index',
          label: 'node-$index',
          weight: index + 1,
        ),
    ];
    final edges = [
      for (var index = 0; index < 5; index++)
        PhotoGraphEdge(
          sourceId: 'node-$index',
          targetId: 'node-${index + 1}',
          weight: 2,
        ),
    ];

    final first = PhotoGraphLayout(
      nodes: nodes,
      edges: edges,
      size: const Size(1200, 900),
    );
    final second = PhotoGraphLayout(
      nodes: nodes,
      edges: edges,
      size: const Size(1200, 900),
    );

    for (final node in nodes) {
      expect(first.positionOf(node.id), second.positionOf(node.id));
    }

    first.settle(maxTicks: 240);
    expect(first.kineticEnergy, lessThan(PhotoGraphLayout.settleThreshold));
  });

  testWidgets('graph view renders nodes on light and dark themes', (
    tester,
  ) async {
    await tester.pumpWidget(_graphApp(OmniNestTheme.light()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('photo-graph-canvas')), findsOneWidget);
    expect(find.text('Japan'), findsOneWidget);
    expect(find.text('2026-08'), findsOneWidget);
    expect(find.text('Alice'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(_graphApp(OmniNestTheme.dark()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('photo-graph-canvas')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('graph view shows empty state when no relations exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          photoCenterControllerProvider.overrideWith(
            _NoopPhotoCenterController.new,
          ),
        ],
        child: MaterialApp(
          theme: OmniNestTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PhotoGraphView(
              state: PhotoCenterState.empty(),
              onOpenPhoto: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No photo relationships are available yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'graph view uses the shared top-bar query without a second input',
    (tester) async {
      final state = PhotoCenterState.empty().copyWith(
        relationGraph: _relation(
          nodes: [
            const PhotoRelationNode(
              type: PhotoRelationNodeType.album,
              key: 'album-1',
              label: 'Japan',
              weight: 1,
            ),
          ],
          edges: [],
        ),
        searchQuery: 'Tokyo',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            photoCenterControllerProvider.overrideWith(
              _NoopPhotoCenterController.new,
            ),
          ],
          child: MaterialApp(
            theme: OmniNestTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: PhotoGraphView(state: state, onOpenPhoto: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Filtering for "Tokyo"'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('graph view stays stable at compact width and larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
        child: _graphApp(OmniNestTheme.light()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
  });
}

Widget _graphApp(ThemeData theme) {
  final state = PhotoCenterState.empty().copyWith(
    relationGraph: _relation(
      nodes: [
        const PhotoRelationNode(
          type: PhotoRelationNodeType.album,
          key: 'album-1',
          label: 'Japan',
          weight: 8,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.time,
          key: '2026-08',
          label: null,
          weight: 6,
        ),
        const PhotoRelationNode(
          type: PhotoRelationNodeType.person,
          key: 'person-1',
          label: 'Alice',
          weight: 3,
        ),
      ],
      edges: [
        const PhotoRelationEdge(
          sourceType: PhotoRelationNodeType.album,
          sourceKey: 'album-1',
          targetType: PhotoRelationNodeType.person,
          targetKey: 'person-1',
          weight: 3,
        ),
      ],
    ),
  );
  return ProviderScope(
    overrides: [
      photoCenterControllerProvider.overrideWith(
        _NoopPhotoCenterController.new,
      ),
    ],
    child: MaterialApp(
      theme: theme,
      themeMode:
          theme.brightness == Brightness.dark
              ? ThemeMode.dark
              : ThemeMode.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PhotoGraphView(state: state, onOpenPhoto: (_) {})),
    ),
  );
}

PhotoRelationGraph _relation({
  required List<PhotoRelationNode> nodes,
  required List<PhotoRelationEdge> edges,
}) {
  return PhotoRelationGraph(nodes: nodes, edges: edges, truncated: false);
}

class _NoopPhotoCenterController extends PhotoCenterController {
  @override
  Future<PhotoCenterState> build() async => PhotoCenterState.empty();

  @override
  Future<void> loadGroups(GroupBy by, {bool force = false}) async {}

  @override
  Future<void> loadFaceClusters({bool propagateError = false}) async {}

  @override
  Future<void> loadRelationGraph({bool force = false}) async {}
}
