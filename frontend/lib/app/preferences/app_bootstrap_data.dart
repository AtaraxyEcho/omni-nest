import 'package:flutter_riverpod/flutter_riverpod.dart';

const appearanceDeviceModeKey = 'appearance.device.theme_mode';
const localeDeviceLanguageKey = 'locale.device.language';
const legacyGlobalThemeModeKey = 'global_theme_mode';
const legacyGlobalLanguageKey = 'global_language';

class AppBootstrapData {
  const AppBootstrapData({
    this.themeModeName = 'system',
    this.languageCode = 'zh',
  });

  final String themeModeName;
  final String languageCode;
}

final appBootstrapDataProvider = Provider<AppBootstrapData>((ref) {
  return const AppBootstrapData();
});
