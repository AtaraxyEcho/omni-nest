import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/app/theme/app_theme_palette.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/auth/auth_session_store_base.dart';
import 'package:omninest/core/widgets/mobile_shell_scope.dart';
import 'package:omninest/core/widgets/mobile_ui.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_shell.dart';

void main() {
  group('ReaderShell', () {
    testWidgets('renders child content', (tester) async {
      // 设置宽屏尺寸以使用桌面布局
      tester.view.physicalSize = const Size(2400, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // 覆盖 session 存储以避免 FlutterSecureStorage 插件依赖
            authSessionStoreProvider.overrideWithValue(
              MemoryAuthSessionStore(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: OmniNestTheme.from(AppThemePalette.dark),
            home: const ReaderShell(
              section: ReaderSection.bookshelf,
              child: Text('test content'),
            ),
          ),
        ),
      );

      // 等待异步 provider 处理
      await tester.pump(const Duration(seconds: 1));

      // 验证子内容已渲染
      expect(find.text('test content'), findsOneWidget);
    });

    testWidgets('hosted narrow layout omits the legacy section selector', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionStoreProvider.overrideWithValue(
              MemoryAuthSessionStore(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: OmniNestTheme.from(AppThemePalette.dark),
            home: const MobileShellScope(
              hosted: true,
              child: ReaderShell(
                section: ReaderSection.bookshelf,
                child: Text('mobile reader content'),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(MobileSegmentedControl<ReaderSection>), findsNothing);
      expect(find.text('mobile reader content'), findsOneWidget);
    });

    testWidgets('hosted narrow library exposes a back control to bookshelf', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      ReaderSection? selectedSection;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authSessionStoreProvider.overrideWithValue(
              MemoryAuthSessionStore(),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            theme: OmniNestTheme.from(AppThemePalette.dark),
            home: MobileShellScope(
              hosted: true,
              child: ReaderShell(
                section: ReaderSection.books,
                onSectionSelected: (section) => selectedSection = section,
                child: const Text('reader library content'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('reader-mobile-section-back')),
      );
      await tester.pump();

      expect(selectedSection, ReaderSection.bookshelf);
    });
  });
}
