import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/app/theme/app_theme_palette.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_repository.dart';
import 'package:omninest/features/photos/presentation/pages/photo_detail_page.dart';

class _MockPhotoRepository extends Mock implements PhotoRepository {}

/// 固定浏览范围的桩 Notifier，供详情页上一张/下一张与幻灯片使用。
class _FixedScopeNotifier extends PhotoBrowseScopeNotifier {
  _FixedScopeNotifier(this.photos);

  final List<PhotoItem> photos;

  @override
  List<PhotoItem> build() => photos;
}

/// 伪造的照片中心控制器，返回空状态以避免网络请求。
class _FakePhotoCenterController extends PhotoCenterController {
  @override
  Future<PhotoCenterState> build() async {
    return PhotoCenterState.empty();
  }
}

PhotoItem _photo(String id, String city) {
  return PhotoItem(
    id: id,
    fileNodeId: 'file-$id',
    title: 'Photo $id',
    format: 'JPEG',
    fileSize: 1024,
    metadataStatus: 'READY',
    favorite: false,
    createdAt: DateTime(2024, 11, 12),
    gpsLocation: <String, dynamic>{'city': city},
  );
}

class _Harness {
  const _Harness({required this.router, required this.child});

  final GoRouter router;
  final Widget child;
}

_Harness _harness({
  List<PhotoItem> scope = const [],
  String initialLocation = '/photos/photo-1',
}) {
  final repository = _MockPhotoRepository();
  when(() => repository.getPhoto(any())).thenAnswer(
    (invocation) async =>
        scope.firstWhere((p) => p.id == invocation.positionalArguments[0]),
  );
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/photos',
        builder:
            (context, state) =>
                const Scaffold(body: Center(child: Text('Photos Home'))),
      ),
      GoRoute(
        path: '/photos/:photoId',
        builder:
            (context, state) =>
                PhotoDetailPage(photoId: state.pathParameters['photoId']!),
      ),
    ],
  );
  return _Harness(
    router: router,
    child: ProviderScope(
      overrides: [
        photoRepositoryProvider.overrideWithValue(repository),
        photoCenterControllerProvider.overrideWith(
          () => _FakePhotoCenterController(),
        ),
        photoBrowseScopeProvider.overrideWith(() => _FixedScopeNotifier(scope)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        theme: OmniNestTheme.from(AppThemePalette.dark),
      ),
    ),
  );
}

Future<void> _pumpDesktop(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(child);
  await tester.pumpAndSettle();
}

void main() {
  final scope = [
    _photo('photo-1', 'Bern'),
    _photo('photo-2', 'Zurich'),
    _photo('photo-3', 'Geneva'),
  ];

  testWidgets('顶栏使用关闭/下载/删除命令且删除不再是永久删除文案', (tester) async {
    await _pumpDesktop(tester, _harness(scope: scope).child);

    expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    expect(find.byTooltip('Download original'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.byTooltip('Permanently Delete'), findsNothing);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });

  testWidgets('幻灯片在查看器内自动推进并循环回第一张', (tester) async {
    await _pumpDesktop(tester, _harness(scope: scope).child);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    expect(find.text('Slideshow · 1 / 3'), findsOneWidget);

    // 第一次推进：photo-1 → photo-2，播放状态跨路由替换保持。
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Slideshow · 2 / 3'), findsOneWidget);

    // 第二次推进：photo-2 → photo-3。
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Slideshow · 3 / 3'), findsOneWidget);

    // 末尾循环回第一张。
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Slideshow · 1 / 3'), findsOneWidget);
  });

  testWidgets('暂停后不再自动推进', (tester) async {
    await _pumpDesktop(tester, _harness(scope: scope).child);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Slideshow · 2 / 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pump();
    expect(find.text('Slideshow · 2 / 3'), findsNothing);

    await tester.pump(const Duration(seconds: 10));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Zurich'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('离开详情后播放状态自动复位，再次进入不恢复播放', (tester) async {
    final harness = _harness(scope: scope, initialLocation: '/photos');
    await _pumpDesktop(tester, harness.child);
    expect(find.text('Photos Home'), findsOneWidget);

    // 从列表 push 进入详情，与生产导航路径一致，关闭时走 pop。
    harness.router.push('/photos/photo-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('Slideshow · 2 / 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Photos Home'), findsOneWidget);

    harness.router.push('/photos/photo-3');
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause_rounded), findsNothing);
    expect(find.textContaining('Slideshow ·'), findsNothing);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });

  testWidgets('页面销毁时幻灯片定时器随之取消', (tester) async {
    await _pumpDesktop(tester, _harness(scope: scope).child);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    await tester.pumpWidget(const SizedBox());
    // 若定时器未取消，测试结束时会被标记为 pending timer。
    await tester.pump(const Duration(seconds: 10));
  });

  testWidgets('桌面端信息面板是全高独立侧栏并压缩照片区', (tester) async {
    await _pumpDesktop(tester, _harness(scope: scope).child);

    // 收起时 AnimatedSize 宽度为 0，不占舞台空间。
    expect(tester.getSize(find.byType(AnimatedSize)).width, 0);
    await tester.tap(find.byIcon(Icons.info_outline_rounded));
    await tester.pumpAndSettle();

    final panelSize = tester.getSize(find.byType(AnimatedSize));
    expect(panelSize.width, 288);
    expect(panelSize.height, 800);
    expect(find.text('Photo Info'), findsOneWidget);
  });

  testWidgets('紧凑端信息面板为右侧抽屉且点击遮罩关闭', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_harness(scope: scope).child);
    await tester.pumpAndSettle();

    // 紧凑端不存在桌面侧栏，信息入口在弹出菜单中。
    expect(find.byType(AnimatedSize), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show Info').last);
    await tester.pumpAndSettle();

    expect(find.text('Photo Info'), findsOneWidget);
    expect(find.byType(AnimatedSize), findsNothing);

    await tester.tapAt(const Offset(20, 400));
    await tester.pumpAndSettle();
    expect(find.text('Photo Info'), findsNothing);
  });
}
