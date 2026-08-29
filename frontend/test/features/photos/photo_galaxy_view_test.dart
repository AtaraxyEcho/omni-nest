import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_album.dart';
import 'package:omninest/features/photos/domain/photo_face_cluster.dart';
import 'package:omninest/features/photos/domain/photo_group.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_galaxy_models.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_galaxy_view.dart';

void main() {
  test('all mode combines albums and loaded relation groups', () {
    final photo = _photo('photo-1', 'Tokyo.jpg');
    final state = PhotoCenterState.empty().copyWith(
      albums: [
        PhotoAlbum(
          id: 'album-1',
          name: 'Japan',
          description: '',
          photoCount: 1,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      groups: [
        PhotoGroup(groupKey: '2026-08', photoCount: 1, photos: [photo]),
      ],
    );

    final clusters = buildPhotoGalaxyClusters(state, PhotoGalaxyMode.all);

    expect(clusters.map((cluster) => cluster.id), [
      'album:album-1',
      'group:2026-08',
    ]);
    expect(clusters.last.photos.single.title, 'Tokyo.jpg');
  });

  test('all mode creates an unsorted galaxy when no relationships exist', () {
    final state = PhotoCenterState.empty().copyWith(
      photos: [_photo('photo-1', 'Unsorted.jpg')],
      photoTotalElements: 1,
    );

    final clusters = buildPhotoGalaxyClusters(state, PhotoGalaxyMode.all);

    expect(clusters, hasLength(1));
    expect(clusters.single.kind, PhotoGalaxyClusterKind.unassigned);
    expect(clusters.single.photoCount, 1);
  });

  test('all mode keeps loaded photos outside relation previews visible', () {
    final related = _photo('photo-1', 'Related.jpg');
    final unassigned = _photo('photo-2', 'Unsorted.jpg');
    final state = PhotoCenterState.empty().copyWith(
      photos: [related, unassigned],
      groups: [
        PhotoGroup(groupKey: '2026-08', photoCount: 1, photos: [related]),
      ],
      photoTotalElements: 2,
    );

    final clusters = buildPhotoGalaxyClusters(state, PhotoGalaxyMode.all);
    final unsorted = clusters.singleWhere(
      (cluster) => cluster.kind == PhotoGalaxyClusterKind.unassigned,
    );

    expect(unsorted.photos.map((photo) => photo.id), ['photo-2']);
    expect(unsorted.photoCount, 1);
  });

  test('all mode ignores relation groups from another active dimension', () {
    final state = PhotoCenterState.empty().copyWith(
      groups: [PhotoGroup(groupKey: 'Tokyo', photoCount: 1, photos: [])],
      groupBy: GroupBy.location,
    );

    final clusters = buildPhotoGalaxyClusters(state, PhotoGalaxyMode.all);

    expect(clusters, isEmpty);
  });

  test('people mode exposes face clusters as galaxies', () {
    final state = PhotoCenterState.empty().copyWith(
      faceClusters: [
        const PhotoFaceCluster(
          id: 'person-1',
          name: 'Alice',
          faceCount: 4,
          coverPhotoUrl: 'https://example.test/alice.jpg',
        ),
      ],
    );

    final clusters = buildPhotoGalaxyClusters(state, PhotoGalaxyMode.people);

    expect(clusters.single.id, 'person:person-1');
    expect(clusters.single.title, 'Alice');
    expect(clusters.single.photoCount, 4);
    expect(clusters.single.countKind, PhotoGalaxyCountKind.faces);
  });

  test('galaxy modes expose only backed relation dimensions', () {
    expect(PhotoGalaxyMode.values, hasLength(4));
  });

  test('cluster search matches title, photo title, and tags', () {
    final photo = _photo('photo-1', 'Kyoto.jpg', tags: ['travel']);
    final cluster = PhotoGalaxyCluster(
      id: 'group:trip',
      title: 'Japan trip',
      photoCount: 1,
      photos: [photo],
      kind: PhotoGalaxyClusterKind.group,
    );

    expect(cluster.matches('japan'), isTrue);
    expect(cluster.matches('kyoto'), isTrue);
    expect(cluster.matches('travel'), isTrue);
    expect(cluster.matches('concert'), isFalse);
  });

  testWidgets('galaxy view renders universe without map dependencies', (
    tester,
  ) async {
    final state = PhotoCenterState.empty().copyWith(
      photos: [_photo('photo-1', 'Memory.jpg')],
      photoTotalElements: 1,
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
            body: PhotoGalaxyView(state: state, onOpenPhoto: (_) {}),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Memory Galaxy'), findsNothing);
    expect(
      find.text('Explore the relationships between your photos.'),
      findsNothing,
    );
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(find.text('Unsorted memories'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'galaxy view uses the shared top-bar query without a second input',
    (tester) async {
      final state = PhotoCenterState.empty().copyWith(
        photos: [_photo('photo-1', 'Tokyo.jpg')],
        photoTotalElements: 1,
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
              body: PhotoGalaxyView(state: state, onOpenPhoto: (_) {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('Filtering for "Tokyo"'), findsOneWidget);
      expect(find.text('Unsorted memories'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('galaxy canvas uses the light theme token', (tester) async {
    await tester.pumpWidget(_galaxyApp(OmniNestTheme.light()));
    await tester.pump();

    final canvas = tester.widget<DecoratedBox>(
      find.byKey(const Key('photo-galaxy-canvas')),
    );
    final expected =
        OmniNestTheme.light().extension<PhotosColors>()!.galaxyCanvas;
    expect((canvas.decoration as BoxDecoration).color, expected);
    expect(ThemeData.estimateBrightnessForColor(expected), Brightness.light);
    expect(tester.takeException(), isNull);
  });

  testWidgets('galaxy canvas uses the dark theme token', (tester) async {
    await tester.pumpWidget(_galaxyApp(OmniNestTheme.dark()));
    await tester.pump();

    final canvas = tester.widget<DecoratedBox>(
      find.byKey(const Key('photo-galaxy-canvas')),
    );
    final expected =
        OmniNestTheme.dark().extension<PhotosColors>()!.galaxyCanvas;
    expect((canvas.decoration as BoxDecoration).color, expected);
    expect(ThemeData.estimateBrightnessForColor(expected), Brightness.dark);
    expect(tester.takeException(), isNull);
  });

  testWidgets('galaxy view stays stable at compact width and larger text', (
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
        child: _galaxyApp(OmniNestTheme.light()),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Widget _galaxyApp(ThemeData theme) {
  final state = PhotoCenterState.empty().copyWith(
    photos: [_photo('photo-1', 'Memory.jpg')],
    photoTotalElements: 1,
  );
  return ProviderScope(
    overrides: [
      photoCenterControllerProvider.overrideWith(
        _NoopPhotoCenterController.new,
      ),
    ],
    child: MaterialApp(
      theme: theme,
      themeMode: ThemeMode.light,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: PhotoGalaxyView(state: state, onOpenPhoto: (_) {})),
    ),
  );
}

class _NoopPhotoCenterController extends PhotoCenterController {
  @override
  Future<PhotoCenterState> build() async => PhotoCenterState.empty();

  @override
  Future<void> loadGroups(GroupBy by, {bool force = false}) async {}

  @override
  Future<void> loadFaceClusters({bool propagateError = false}) async {}
}

PhotoItem _photo(String id, String title, {List<String> tags = const []}) {
  return PhotoItem(
    id: id,
    fileNodeId: 'file-$id',
    title: title,
    format: 'JPEG',
    fileSize: 1,
    metadataStatus: 'READY',
    favorite: false,
    createdAt: DateTime(2026),
    tags: tags,
  );
}
