import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/setup/application/initial_setup_controller.dart';
import 'package:omninest/features/setup/domain/initial_setup_status.dart';
import 'package:omninest/features/setup/presentation/pages/initial_setup_page.dart';

void main() {
  testWidgets('首次安装向导在桌面端和移动端均保持可滚动且不溢出', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in const [Size(360, 760), Size(1280, 800)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            initialSetupProvider.overrideWith(_AvailableSetupNotifier.new),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: OmniNestTheme.light(),
            home: const InitialSetupPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('创建超级管理员'), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsWidgets);
      expect(tester.takeException(), isNull, reason: '尺寸 $size 出现布局异常');
    }
  });
}

class _AvailableSetupNotifier extends InitialSetupController {
  @override
  Future<InitialSetupStatus> build() async {
    return const InitialSetupStatus(setupRequired: true, setupAvailable: true);
  }
}
