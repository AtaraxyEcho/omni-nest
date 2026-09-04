import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/locale/application/locale_controller.dart';
import 'package:omninest/app/preferences/app_bootstrap_data.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/widgets/user_avatar_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('浅色模式头像菜单统一使用 Portal 主题容器色', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(_TestAuthSessionNotifier.new),
        ],
        child: MaterialApp(
          theme: OmniNestTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: UserAvatarMenu())),
        ),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(UserAvatarMenu));
    final colors = Theme.of(context).colorScheme;
    final popup = tester.widget<Widget>(
      find.byWidgetPredicate((widget) => widget is PopupMenuButton),
    );

    expect((popup as dynamic).color, colors.surfaceContainerLow);
    expect((popup as dynamic).surfaceTintColor, Colors.transparent);
  });

  testWidgets('头像菜单语言切换项更新全局语言状态', (tester) async {
    // 设备已存语言为 zh，避免测试环境系统 locale（en）被“跟随系统”逻辑采纳
    SharedPreferences.setMockInitialValues(<String, Object>{
      localeDeviceLanguageKey: 'zh',
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authSessionProvider.overrideWith(_TestAuthSessionNotifier.new),
        ],
        child: MaterialApp(
          theme: OmniNestTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: UserAvatarMenu())),
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(UserAvatarMenu)),
    );
    expect(container.read(localeControllerProvider), 'zh');

    await tester.tap(find.byType(UserAvatarMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(container.read(localeControllerProvider), 'en');
  });
}

class _TestAuthSessionNotifier extends AuthSessionNotifier {
  @override
  Future<AuthSessionState> build() async {
    return const AuthSessionState.unauthenticated();
  }
}
