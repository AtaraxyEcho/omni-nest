import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/app/theme/app_theme_palette.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/auth/auth_session_store_base.dart';
import 'package:omninest/features/files/presentation/widgets/media_import_button.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/presentation/pages/photos_page.dart';

/// 伪造的照片中心控制器，返回空状态以避免网络请求
class _FakePhotoCenterController extends PhotoCenterController {
  _FakePhotoCenterController([this.initialState]);

  final PhotoCenterState? initialState;

  @override
  Future<PhotoCenterState> build() async {
    return initialState ?? PhotoCenterState.empty();
  }
}

void main() {
  group('PhotosPage', () {
    testWidgets('renders without crashing', (tester) async {
      // 设置宽屏尺寸以使用桌面布局
      tester.view.physicalSize = const Size(2400, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 创建简单的 GoRouter，因为 PhotosPage 的 initState 调用 GoRouter.of(context)
      final router = GoRouter(
        initialLocation: '/photos',
        routes: [
          GoRoute(
            path: '/photos',
            builder: (context, state) => const PhotosPage(),
          ),
          GoRoute(
            path: '/portal',
            builder: (context, state) => const SizedBox(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // 覆盖 session 存储以避免 FlutterSecureStorage 插件依赖
            authSessionStoreProvider.overrideWithValue(
              MemoryAuthSessionStore(),
            ),
            // 覆盖照片控制器以避免网络请求
            photoCenterControllerProvider.overrideWith(
              () => _FakePhotoCenterController(),
            ),
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

      // 等待异步 provider 处理
      await tester.pump(const Duration(seconds: 1));

      // 验证页面已渲染
      expect(find.byType(PhotosPage), findsOneWidget);
    });

    testWidgets('desktop layout exposes sidebar search and scrollable grid', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2400, 1200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final photos = List<PhotoItem>.generate(
        30,
        (index) => PhotoItem(
          id: 'photo-$index',
          fileNodeId: 'file-$index',
          title: 'Photo $index',
          format: 'JPEG',
          fileSize: 1024,
          metadataStatus: 'READY',
          favorite: false,
          createdAt: DateTime(2026, 7, 13),
        ),
      );
      final router = GoRouter(
        initialLocation: '/photos',
        routes: [
          GoRoute(
            path: '/photos',
            builder: (context, state) => const PhotosPage(),
          ),
          GoRoute(
            path: '/portal',
            builder: (context, state) => const SizedBox(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionStoreProvider.overrideWithValue(
              MemoryAuthSessionStore(),
            ),
            photoCenterControllerProvider.overrideWith(
              () => _FakePhotoCenterController(
                PhotoCenterState.empty().copyWith(photos: photos),
              ),
            ),
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
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Albums'), findsOneWidget);
      final importButton = tester.widget<MediaImportButton>(
        find.byType(MediaImportButton),
      );
      expect(importButton.acceptedExtensions, isNot(contains('webp')));
      expect(importButton.unsupportedExtensions, isEmpty);
      final grid = tester.widget<GridView>(find.byType(GridView));
      expect(grid.shrinkWrap, isFalse);
      expect(grid.physics, isNot(isA<NeverScrollableScrollPhysics>()));
    });
  });
}
