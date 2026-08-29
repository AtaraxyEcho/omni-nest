import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/environment.dart';
import 'package:omninest/app/providers.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/auth/auth_models.dart';
import 'package:omninest/core/errors/app_exception.dart';
import 'package:omninest/core/network/api_client.dart';
import 'package:omninest/core/preferences/preference_snapshot.dart';
import 'package:omninest/core/preferences/user_preferences_api.dart';
import 'package:omninest/features/music/application/music_visualizer_preset_controller.dart';
import 'package:omninest/features/music/domain/music_visualizer_preset.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('旧远端视觉作用域自动迁移为单一设置', () async {
    final api =
        _FakeUserPreferencesApi()
          ..values['portal.music_visualizer'] = const <String, dynamic>{
            'selectedPresetId': 'custom_demo',
            'customPresets': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'custom_demo',
                'player': <String, dynamic>{'enabled': false},
              },
            ],
          };
    final container = ProviderContainer.test(
      overrides: [
        userPreferencesApiProvider.overrideWithValue(api),
        authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    final preferences = await container.read(
      musicVisualizerPreferencesProvider.future,
    );

    expect(preferences.visual.player.enabled, isFalse);
    expect(
      api.updates['music.player.visual.v1'],
      containsPair('schemaVersion', 5),
    );
    expect(api.deletedScopes, contains('portal.music_visualizer'));
    expect(api.values.containsKey('portal.music_visualizer'), isFalse);
  });

  test('旧远端视觉作用域删除失败时迁移结果仍可用并在恢复后重放', () async {
    final api =
        _FakeUserPreferencesApi()
          ..values['portal.music_visualizer'] = const <String, dynamic>{
            'selectedPresetId': 'custom_demo',
            'customPresets': <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'custom_demo',
                'player': <String, dynamic>{'enabled': false},
              },
            ],
          }
          ..failNextDelete = true;
    final container = ProviderContainer.test(
      overrides: [
        userPreferencesApiProvider.overrideWithValue(api),
        authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    final preferences = await container.read(
      musicVisualizerPreferencesProvider.future,
    );

    expect(preferences.visual.player.enabled, isFalse);
    expect(api.values.containsKey('portal.music_visualizer'), isTrue);

    await container
        .read(preferenceSyncServiceProvider)
        .load(userId: 'user-1', scope: 'portal.music_visualizer');
    expect(api.values.containsKey('portal.music_visualizer'), isFalse);
    expect(api.deletedScopes, contains('portal.music_visualizer'));
  });

  test('旧本地键自动迁移且支持恢复默认设置', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'portal_music_visualizer_preferences': jsonEncode(const <String, dynamic>{
        'selectedPresetId': 'custom-test',
        'customPresets': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'custom-test',
            'player': <String, dynamic>{'audioBarEnabled': false},
          },
        ],
      }),
    });
    final api = _FakeUserPreferencesApi();
    final container = ProviderContainer.test(
      overrides: [
        userPreferencesApiProvider.overrideWithValue(api),
        authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    final migrated = await container.read(
      musicVisualizerPreferencesProvider.future,
    );
    expect(migrated.visual.player.audioBarEnabled, isFalse);

    await container
        .read(musicVisualizerPreferencesProvider.notifier)
        .restoreDefaults();
    final restored = container.read(musicVisualizerPreferencesProvider).value!;
    expect(restored.visual.player.enabled, isTrue);
    expect(restored.visual.player.audioBarEnabled, isTrue);
  });

  test('保存视觉设置同步到本地和远端', () async {
    final api = _FakeUserPreferencesApi();
    final container = ProviderContainer.test(
      overrides: [
        userPreferencesApiProvider.overrideWithValue(api),
        authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(musicVisualizerPreferencesProvider.future);

    final visual = PortalMusicVisualizerSettings.defaults.copyWith(
      player: PortalGlassPlayerSettings.defaults.copyWith(enabled: false),
    );
    await container
        .read(musicVisualizerPreferencesProvider.notifier)
        .saveVisual(visual);

    expect(
      container
          .read(musicVisualizerPreferencesProvider)
          .value!
          .visual
          .player
          .enabled,
      isFalse,
    );
    expect(api.updates['music.player.visual.v1']?['visual'], isA<Map>());
  });

  test('歌词与音频条视觉参数可完整序列化', () {
    final preferences = PortalMusicVisualizerPreferences(
      visual: PortalMusicVisualizerSettings.defaults.copyWith(
        lyrics: PortalLyricVisualSettings.defaults.copyWith(
          visibleLines: 7,
          lineSpacing: 1.4,
          activeColorValue: 0xFFB7FFE7,
          readColorValue: 0xFF7098A0,
          unreadColorValue: 0xFFFFFFFF,
          breathingEnabled: false,
          glowIntensity: 1.6,
          glowColorValue: 0xFF4AD5FF,
          position: PortalLyricPosition.right,
        ),
        player: PortalGlassPlayerSettings.defaults.copyWith(
          audioBarStyle: MusicAudioBarStyle.pulseDots,
        ),
      ),
    );

    final restored = PortalMusicVisualizerPreferences.fromJson(
      preferences.toJson(),
    );

    expect(restored.schemaVersion, 5);
    expect(restored.visual.lyrics.visibleLines, 7);
    expect(restored.visual.lyrics.lineSpacing, 1.4);
    expect(restored.visual.lyrics.activeColorValue, 0xFFB7FFE7);
    expect(restored.visual.lyrics.readColorValue, 0xFF7098A0);
    expect(restored.visual.lyrics.unreadColorValue, 0xFFFFFFFF);
    expect(restored.visual.lyrics.breathingEnabled, isFalse);
    expect(restored.visual.lyrics.glowIntensity, 1.6);
    expect(restored.visual.lyrics.glowColorValue, 0xFF4AD5FF);
    expect(restored.visual.lyrics.position, PortalLyricPosition.right);
    expect(restored.visual.player.audioBarStyle, MusicAudioBarStyle.pulseDots);
  });

  test('旧歌词颜色与镜像波形迁移到当前设置结构', () {
    final restored = PortalMusicVisualizerPreferences.fromJson(
      const <String, dynamic>{
        'schemaVersion': 4,
        'visual': <String, dynamic>{
          'lyrics': <String, dynamic>{
            'textColorValue': 0xFFAABBCC,
            'showAllLines': true,
          },
          'player': <String, dynamic>{'audioBarStyle': 'mirroredWave'},
        },
      },
    );

    expect(restored.schemaVersion, 5);
    expect(restored.visual.lyrics.activeColorValue, 0xFFAABBCC);
    expect(
      restored.visual.lyrics.unreadColorValue,
      PortalLyricVisualSettings.defaults.unreadColorValue,
    );
    expect(restored.visual.player.audioBarStyle, MusicAudioBarStyle.lineWave);
  });

  test('默认频段响应强调低频并抑制高频抖动', () {
    expect(PortalSpectrumVisualSettings.defaults.lowResponse, 1.08);
    expect(PortalSpectrumVisualSettings.defaults.midResponse, 0.96);
    expect(PortalSpectrumVisualSettings.defaults.highResponse, 0.82);
    expect(MusicAudioBarStyle.values, <MusicAudioBarStyle>[
      MusicAudioBarStyle.spectrumBars,
      MusicAudioBarStyle.lineWave,
      MusicAudioBarStyle.pulseDots,
    ]);
  });
}

class _AuthenticatedSessionNotifier extends AuthSessionNotifier {
  @override
  Future<AuthSessionState> build() async {
    return AuthSessionState(
      user: UserProfile(id: 'user-1', username: 'tester', role: 'MEMBER'),
    );
  }
}

class _FakeUserPreferencesApi extends UserPreferencesApi {
  _FakeUserPreferencesApi()
    : super(
        ApiClient(
          const AppEnvironment(
            apiBaseUrl: 'http://localhost:8080/api/v1',
            wsBaseUrl: 'ws://localhost:8080/ws',
          ),
        ),
      );

  final Map<String, Map<String, dynamic>> values =
      <String, Map<String, dynamic>>{};
  final Map<String, Map<String, dynamic>> updates =
      <String, Map<String, dynamic>>{};
  final Map<String, int> versions = <String, int>{};
  final List<String> deletedScopes = <String>[];
  bool failNextDelete = false;

  @override
  Future<PreferenceSnapshot> getSnapshot(String scope) async {
    return PreferenceSnapshot(
      scope: scope,
      preferences: values[scope] ?? const <String, dynamic>{},
      version: values.containsKey(scope) ? (versions[scope] ?? 0) : null,
    );
  }

  @override
  Future<PreferenceSnapshot> patch({
    required String scope,
    required int? baseVersion,
    required Map<String, dynamic> changes,
    Set<String> removeKeys = const <String>{},
  }) async {
    final preferences = Map<String, dynamic>.from(
      values[scope] ?? const <String, dynamic>{},
    )..addAll(changes);
    for (final key in removeKeys) {
      preferences.remove(key);
    }
    values[scope] = preferences;
    updates[scope] = Map<String, dynamic>.from(changes);
    versions[scope] = (versions[scope] ?? -1) + 1;
    return PreferenceSnapshot(
      scope: scope,
      preferences: preferences,
      version: versions[scope],
    );
  }

  @override
  Future<void> delete({required String scope, required int baseVersion}) async {
    if (failNextDelete) {
      failNextDelete = false;
      throw const AppException(code: 'OFFLINE', message: 'offline');
    }
    deletedScopes.add(scope);
    values.remove(scope);
    versions.remove(scope);
  }
}
