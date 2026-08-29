import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/widgets/user_avatar_menu.dart';

void main() {
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
}

class _TestAuthSessionNotifier extends AuthSessionNotifier {
  @override
  Future<AuthSessionState> build() async {
    return const AuthSessionState.unauthenticated();
  }
}
