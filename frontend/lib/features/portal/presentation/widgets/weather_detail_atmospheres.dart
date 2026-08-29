part of 'weather_detail_dialog.dart';

class _Atmosphere {
  const _Atmosphere({
    required this.top,
    required this.mid,
    required this.bottom,
    required this.particleColor,
    required this.textColor,
    required this.textSecondary,
    required this.panelBg,
  });

  final Color top;
  final Color mid;
  final Color bottom;
  final Color particleColor;
  final Color textColor;
  final Color textSecondary;
  final Color panelBg;

  static const sunny = _Atmosphere(
    top: Color(0xFF72C7F8),
    mid: Color(0xFFAEDCFF),
    bottom: Color(0xFFFFF3D6),
    particleColor: Color(0xFFFFD866),
    textColor: Color(0xFF12304A),
    textSecondary: Color(0xFF31536B),
    panelBg: Color(0x40FFFFFF),
  );
  static const partlyCloudy = _Atmosphere(
    top: Color(0xFF42A5F5),
    mid: Color(0xFF90CAF9),
    bottom: Color(0xFFE3F2FD),
    particleColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF1A237E),
    textSecondary: Color(0xFF283593),
    panelBg: Color(0x38FFFFFF),
  );
  static const cloudy = _Atmosphere(
    top: Color(0xFF455A64),
    mid: Color(0xFF607D8B),
    bottom: Color(0xFF90A4AE),
    particleColor: Color(0xFFB0BEC5),
    textColor: Color(0xFFECEFF1),
    textSecondary: Color(0xFFCFD8DC),
    panelBg: Color(0x45FFFFFF),
  );
  static const rain = _Atmosphere(
    top: Color(0xFF1A2332),
    mid: Color(0xFF263244),
    bottom: Color(0xFF37474F),
    particleColor: Color(0xFF80CBC4),
    textColor: Color(0xFFE0F2F1),
    textSecondary: Color(0xFFB2DFDB),
    panelBg: Color(0x50FFFFFF),
  );
  static const storm = _Atmosphere(
    top: Color(0xFF0D1117),
    mid: Color(0xFF161B22),
    bottom: Color(0xFF21262D),
    particleColor: Color(0xFF78909C),
    textColor: Color(0xFFE6EDF3),
    textSecondary: Color(0xFF8B949E),
    panelBg: Color(0x50FFFFFF),
  );
  static const snow = _Atmosphere(
    top: Color(0xFF37474F),
    mid: Color(0xFF607D8B),
    bottom: Color(0xFFCFD8DC),
    particleColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF263238),
    textSecondary: Color(0xFF455A64),
    panelBg: Color(0x40FFFFFF),
  );
  static const fog = _Atmosphere(
    top: Color(0xFF607D8B),
    mid: Color(0xFF78909C),
    bottom: Color(0xFFB0BEC5),
    particleColor: Color(0xB3FFFFFF),
    textColor: Color(0xFF263238),
    textSecondary: Color(0xFF455A64),
    panelBg: Color(0x40FFFFFF),
  );
  static const haze = _Atmosphere(
    top: Color(0xFF737D83),
    mid: Color(0xFF9BA2A6),
    bottom: Color(0xFFD4D2C9),
    particleColor: Color(0xD6F2F0E8),
    textColor: Color(0xFF263238),
    textSecondary: Color(0xFF526068),
    panelBg: Color(0x42FFFFFF),
  );
  static const dust = _Atmosphere(
    top: Color(0xFF816B4C),
    mid: Color(0xFFB59663),
    bottom: Color(0xFFD8C79D),
    particleColor: Color(0xCCE9D7A8),
    textColor: Color(0xFF2F241A),
    textSecondary: Color(0xFF604B31),
    panelBg: Color(0x3FFFFFFF),
  );
  static const heat = _Atmosphere(
    top: Color(0xFF7ABDF2),
    mid: Color(0xFFFFD082),
    bottom: Color(0xFFFFF0C4),
    particleColor: Color(0xFFFFD25F),
    textColor: Color(0xFF4A2D0A),
    textSecondary: Color(0xFF79531A),
    panelBg: Color(0x3FFFFFFF),
  );
  static const cold = _Atmosphere(
    top: Color(0xFF9EC8E8),
    mid: Color(0xFFC6DFF1),
    bottom: Color(0xFFF0F7FB),
    particleColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF153348),
    textSecondary: Color(0xFF426275),
    panelBg: Color(0x42FFFFFF),
  );

  static const nightClear = _Atmosphere(
    top: Color(0xFF0D1B2A),
    mid: Color(0xFF1B2838),
    bottom: Color(0xFF2C3E50),
    particleColor: Color(0xCCFFFFFF),
    textColor: Color(0xFFE8EAF6),
    textSecondary: Color(0xFF9FA8DA),
    panelBg: Color(0x50FFFFFF),
  );
  static const nightCloudy = _Atmosphere(
    top: Color(0xFF121820),
    mid: Color(0xFF1A2332),
    bottom: Color(0xFF263238),
    particleColor: Color(0x99FFFFFF),
    textColor: Color(0xFFCFD8DC),
    textSecondary: Color(0xFF78909C),
    panelBg: Color(0x50FFFFFF),
  );
  static const nightRain = _Atmosphere(
    top: Color(0xFF07111D),
    mid: Color(0xFF0D1B2A),
    bottom: Color(0xFF172536),
    particleColor: Color(0xFFCFEFFF),
    textColor: Color(0xFFEAF7FF),
    textSecondary: Color(0xFFB7D7EA),
    panelBg: Color(0x54FFFFFF),
  );
  static const nightStorm = _Atmosphere(
    top: Color(0xFF05070D),
    mid: Color(0xFF0A101A),
    bottom: Color(0xFF151C28),
    particleColor: Color(0xFFD6E8FF),
    textColor: Color(0xFFEAF2FF),
    textSecondary: Color(0xFFAAB7C7),
    panelBg: Color(0x56FFFFFF),
  );
  static const nightSnow = _Atmosphere(
    top: Color(0xFF111B2A),
    mid: Color(0xFF243346),
    bottom: Color(0xFF405062),
    particleColor: Color(0xFFFFFFFF),
    textColor: Color(0xFFF4FAFF),
    textSecondary: Color(0xFFD7E4EF),
    panelBg: Color(0x46FFFFFF),
  );
  static const nightFog = _Atmosphere(
    top: Color(0xFF182431),
    mid: Color(0xFF2C3A45),
    bottom: Color(0xFF55636B),
    particleColor: Color(0xD6FFFFFF),
    textColor: Color(0xFFF1F7FA),
    textSecondary: Color(0xFFD0DCE2),
    panelBg: Color(0x48FFFFFF),
  );
  static const nightHaze = _Atmosphere(
    top: Color(0xFF151B20),
    mid: Color(0xFF2B3338),
    bottom: Color(0xFF586064),
    particleColor: Color(0xCFE8E6DE),
    textColor: Color(0xFFF0F4F6),
    textSecondary: Color(0xFFD1D8DA),
    panelBg: Color(0x48FFFFFF),
  );
  static const nightDust = _Atmosphere(
    top: Color(0xFF201A14),
    mid: Color(0xFF4E3F2A),
    bottom: Color(0xFF806E4D),
    particleColor: Color(0xCCEAD29A),
    textColor: Color(0xFFFFF7E8),
    textSecondary: Color(0xFFEBD7B4),
    panelBg: Color(0x48FFFFFF),
  );
  static const nightHeat = _Atmosphere(
    top: Color(0xFF111B2A),
    mid: Color(0xFF5A3442),
    bottom: Color(0xFFA05B4C),
    particleColor: Color(0xFFFFC36B),
    textColor: Color(0xFFFFF3E7),
    textSecondary: Color(0xFFFFD6B1),
    panelBg: Color(0x48FFFFFF),
  );
  static const nightCold = _Atmosphere(
    top: Color(0xFF0A1724),
    mid: Color(0xFF183047),
    bottom: Color(0xFF45657A),
    particleColor: Color(0xFFFFFFFF),
    textColor: Color(0xFFF4FAFF),
    textSecondary: Color(0xFFD7E7F2),
    panelBg: Color(0x48FFFFFF),
  );
  static const dawnClear = _Atmosphere(
    top: Color(0xFF9FC7EC),
    mid: Color(0xFFD9C4B6),
    bottom: Color(0xFFFFE9C7),
    particleColor: Color(0xFFDDEBFF),
    textColor: Color(0xFF19344C),
    textSecondary: Color(0xFF46657B),
    panelBg: Color(0x42FFFFFF),
  );
  static const dawnCloudy = _Atmosphere(
    top: Color(0xFF72899B),
    mid: Color(0xFFA4AEB6),
    bottom: Color(0xFFD9D2C8),
    particleColor: Color(0xFFDDEBFF),
    textColor: Color(0xFF1D3344),
    textSecondary: Color(0xFF536879),
    panelBg: Color(0x44FFFFFF),
  );
  static const dawnRain = _Atmosphere(
    top: Color(0xFF26374A),
    mid: Color(0xFF43546B),
    bottom: Color(0xFF7A8791),
    particleColor: Color(0xFFD6F5FF),
    textColor: Color(0xFFF3F9FF),
    textSecondary: Color(0xFFD2E2EC),
    panelBg: Color(0x50FFFFFF),
  );
  static const dawnStorm = _Atmosphere(
    top: Color(0xFF101724),
    mid: Color(0xFF263044),
    bottom: Color(0xFF4D5968),
    particleColor: Color(0xFFDDEBFF),
    textColor: Color(0xFFF3F8FF),
    textSecondary: Color(0xFFCBD4E0),
    panelBg: Color(0x55FFFFFF),
  );
  static const dawnSnow = _Atmosphere(
    top: Color(0xFF526A7F),
    mid: Color(0xFF92A9B8),
    bottom: Color(0xFFE9F0F4),
    particleColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF1C3548),
    textSecondary: Color(0xFF567084),
    panelBg: Color(0x42FFFFFF),
  );
  static const dawnFog = _Atmosphere(
    top: Color(0xFF7C909D),
    mid: Color(0xFFAAB7BE),
    bottom: Color(0xFFE2DFD7),
    particleColor: Color(0xE6FFFFFF),
    textColor: Color(0xFF243845),
    textSecondary: Color(0xFF5C6E78),
    panelBg: Color(0x44FFFFFF),
  );
  static const dawnHaze = _Atmosphere(
    top: Color(0xFF7E8B91),
    mid: Color(0xFFB0B2AE),
    bottom: Color(0xFFE4D8C7),
    particleColor: Color(0xDCF5F0E7),
    textColor: Color(0xFF273A44),
    textSecondary: Color(0xFF617077),
    panelBg: Color(0x44FFFFFF),
  );
  static const dawnDust = _Atmosphere(
    top: Color(0xFF927B56),
    mid: Color(0xFFC3A570),
    bottom: Color(0xFFE9D6A8),
    particleColor: Color(0xD6F1DCA5),
    textColor: Color(0xFF352817),
    textSecondary: Color(0xFF684F2C),
    panelBg: Color(0x42FFFFFF),
  );
  static const dawnHeat = _Atmosphere(
    top: Color(0xFF86BFE8),
    mid: Color(0xFFFFC98A),
    bottom: Color(0xFFFFE7BC),
    particleColor: Color(0xFFFFD680),
    textColor: Color(0xFF442B10),
    textSecondary: Color(0xFF795A31),
    panelBg: Color(0x42FFFFFF),
  );
  static const dawnCold = _Atmosphere(
    top: Color(0xFF8DB7D5),
    mid: Color(0xFFC9DDE8),
    bottom: Color(0xFFF4F9FC),
    particleColor: Color(0xFFFFFFFF),
    textColor: Color(0xFF143145),
    textSecondary: Color(0xFF4A6476),
    panelBg: Color(0x42FFFFFF),
  );
  static const dawnDusk = _Atmosphere(
    top: Color(0xFF5C3D6E),
    mid: Color(0xFFB85C38),
    bottom: Color(0xFFE8A87C),
    particleColor: Color(0xCCFFFFFF),
    textColor: Color(0xFFFFF3E0),
    textSecondary: Color(0xFFFFCCBC),
    panelBg: Color(0x45FFFFFF),
  );
  static const duskCloudy = _Atmosphere(
    top: Color(0xFF3E354D),
    mid: Color(0xFF75616C),
    bottom: Color(0xFFA68880),
    particleColor: Color(0xFFE8D7CF),
    textColor: Color(0xFFFFF5EC),
    textSecondary: Color(0xFFFFDCC9),
    panelBg: Color(0x46FFFFFF),
  );
  static const duskRain = _Atmosphere(
    top: Color(0xFF24283A),
    mid: Color(0xFF3F4254),
    bottom: Color(0xFF6B5C62),
    particleColor: Color(0xFFD6F5FF),
    textColor: Color(0xFFF4F8FF),
    textSecondary: Color(0xFFD5DCE8),
    panelBg: Color(0x50FFFFFF),
  );
  static const duskStorm = _Atmosphere(
    top: Color(0xFF11131F),
    mid: Color(0xFF222331),
    bottom: Color(0xFF3A3240),
    particleColor: Color(0xFFDDEBFF),
    textColor: Color(0xFFF2F6FF),
    textSecondary: Color(0xFFBCC4D2),
    panelBg: Color(0x55FFFFFF),
  );
  static const duskSnow = _Atmosphere(
    top: Color(0xFF333C50),
    mid: Color(0xFF677083),
    bottom: Color(0xFFD7D4D0),
    particleColor: Color(0xFFFFFFFF),
    textColor: Color(0xFFF9FCFF),
    textSecondary: Color(0xFFE3EAF1),
    panelBg: Color(0x45FFFFFF),
  );
  static const duskFog = _Atmosphere(
    top: Color(0xFF4A4452),
    mid: Color(0xFF7E7B82),
    bottom: Color(0xFFC5BDB5),
    particleColor: Color(0xDFFFFFFF),
    textColor: Color(0xFFFFF7F0),
    textSecondary: Color(0xFFEDE2DA),
    panelBg: Color(0x44FFFFFF),
  );
  static const duskHaze = _Atmosphere(
    top: Color(0xFF504A50),
    mid: Color(0xFF8E837C),
    bottom: Color(0xFFC8B9A4),
    particleColor: Color(0xDFFFF4E8),
    textColor: Color(0xFFFFF6EF),
    textSecondary: Color(0xFFEADCD2),
    panelBg: Color(0x44FFFFFF),
  );
  static const duskDust = _Atmosphere(
    top: Color(0xFF5B3F2D),
    mid: Color(0xFF9C7448),
    bottom: Color(0xFFD3AF74),
    particleColor: Color(0xDFF3D28F),
    textColor: Color(0xFFFFF2DC),
    textSecondary: Color(0xFFE9CF9F),
    panelBg: Color(0x44FFFFFF),
  );
  static const duskHeat = _Atmosphere(
    top: Color(0xFF46334B),
    mid: Color(0xFFB35E49),
    bottom: Color(0xFFEFA45A),
    particleColor: Color(0xFFFFC973),
    textColor: Color(0xFFFFF3E7),
    textSecondary: Color(0xFFFFD7B6),
    panelBg: Color(0x46FFFFFF),
  );
  static const duskCold = _Atmosphere(
    top: Color(0xFF33465A),
    mid: Color(0xFF6F8799),
    bottom: Color(0xFFDDE8EE),
    particleColor: Color(0xFFFFFFFF),
    textColor: Color(0xFFF6FBFF),
    textSecondary: Color(0xFFE0ECF4),
    panelBg: Color(0x45FFFFFF),
  );

  static _Atmosphere forScene(WeatherScene s, PortalWeatherProfile profile) {
    return switch (profile.time) {
      PortalWeatherTime.night => switch (s) {
        WeatherScene.sunny => nightClear,
        WeatherScene.partlyCloudy || WeatherScene.cloudy => nightCloudy,
        WeatherScene.rain => nightRain,
        WeatherScene.storm => nightStorm,
        WeatherScene.snow => nightSnow,
        WeatherScene.fog => nightFog,
        WeatherScene.haze => nightHaze,
        WeatherScene.dust => nightDust,
        WeatherScene.heat => nightHeat,
        WeatherScene.cold => nightCold,
      },
      PortalWeatherTime.dawn => switch (s) {
        WeatherScene.sunny || WeatherScene.partlyCloudy => dawnClear,
        WeatherScene.cloudy => dawnCloudy,
        WeatherScene.rain => dawnRain,
        WeatherScene.storm => dawnStorm,
        WeatherScene.snow => dawnSnow,
        WeatherScene.fog => dawnFog,
        WeatherScene.haze => dawnHaze,
        WeatherScene.dust => dawnDust,
        WeatherScene.heat => dawnHeat,
        WeatherScene.cold => dawnCold,
      },
      PortalWeatherTime.dusk => switch (s) {
        WeatherScene.sunny || WeatherScene.partlyCloudy => dawnDusk,
        WeatherScene.cloudy => duskCloudy,
        WeatherScene.rain => duskRain,
        WeatherScene.storm => duskStorm,
        WeatherScene.snow => duskSnow,
        WeatherScene.fog => duskFog,
        WeatherScene.haze => duskHaze,
        WeatherScene.dust => duskDust,
        WeatherScene.heat => duskHeat,
        WeatherScene.cold => duskCold,
      },
      PortalWeatherTime.day => forSceneIgnoreTime(s),
    };
  }

  static _Atmosphere forSceneIgnoreTime(WeatherScene s) => switch (s) {
    WeatherScene.sunny => sunny,
    WeatherScene.partlyCloudy => partlyCloudy,
    WeatherScene.cloudy => cloudy,
    WeatherScene.rain => rain,
    WeatherScene.storm => storm,
    WeatherScene.snow => snow,
    WeatherScene.fog => fog,
    WeatherScene.haze => haze,
    WeatherScene.dust => dust,
    WeatherScene.heat => heat,
    WeatherScene.cold => cold,
  };
}
