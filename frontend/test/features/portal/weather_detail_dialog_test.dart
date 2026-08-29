import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/features/portal/application/weather_provider.dart';
import 'package:omninest/features/portal/presentation/widgets/weather_detail_dialog.dart';

void main() {
  testWidgets('天气详情首帧延迟启动重量级背景动效', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showWeatherDetailDialog(
                      context,
                      weather: WeatherData.empty(),
                    ),
                child: const Text('打开天气'),
              ),
        ),
      ),
    );

    await tester.tap(find.text('打开天气'));
    await tester.pump();

    expect(find.byKey(const ValueKey('weather-scene-effects')), findsNothing);

    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byKey(const ValueKey('weather-scene-effects')), findsOneWidget);
  });
}
