import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/providers.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/features/music/domain/music_visualizer_preset.dart';
import 'package:shared_preferences/shared_preferences.dart';

const musicVisualizerPreferenceScope = 'music.player.visual.v1';

final musicVisualizerPreferencesProvider = AsyncNotifierProvider<
  MusicVisualizerPreferencesNotifier,
  PortalMusicVisualizerPreferences
>(MusicVisualizerPreferencesNotifier.new);

class MusicVisualizerPreferencesNotifier
    extends AsyncNotifier<PortalMusicVisualizerPreferences> {
  static const _legacyScope = 'portal.music_visualizer';
  static const _legacyLocalKey = 'music_player_visual_v1';
  static const _olderLegacyLocalKey = 'portal_music_visualizer_preferences';

  String? _userId;

  @override
  Future<PortalMusicVisualizerPreferences> build() async {
    final local = await _loadLegacyLocal();
    final session = await ref.watch(authSessionProvider.future);
    _userId = session.user?.id;
    final userId = _userId;
    if (userId == null) {
      return local;
    }
    final service = ref.read(preferenceSyncServiceProvider);
    var snapshot = await service.load(
      userId: userId,
      scope: musicVisualizerPreferenceScope,
    );
    if (snapshot.preferences.isNotEmpty) {
      await _clearLegacyLocal();
      return PortalMusicVisualizerPreferences.fromJson(snapshot.preferences);
    }

    final legacySnapshot = await service.load(
      userId: userId,
      scope: _legacyScope,
    );
    final migrated =
        legacySnapshot.preferences.isEmpty
            ? local
            : PortalMusicVisualizerPreferences.fromJson(
              legacySnapshot.preferences,
            );
    snapshot = await service.patch(
      userId: userId,
      scope: musicVisualizerPreferenceScope,
      changes: migrated.toJson(),
    );
    if (legacySnapshot.version != null) {
      await service.delete(userId: userId, scope: _legacyScope);
    }
    await _clearLegacyLocal();
    return PortalMusicVisualizerPreferences.fromJson(snapshot.preferences);
  }

  Future<void> saveVisual(PortalMusicVisualizerSettings visual) async {
    final current =
        state.asData?.value ?? const PortalMusicVisualizerPreferences();
    await _save(current.copyWith(visual: visual));
  }

  Future<void> restoreDefaults() async {
    await _save(const PortalMusicVisualizerPreferences());
  }

  /// 从远端重新同步播放器视觉偏好，并保留本地待提交变更。
  Future<void> refreshFromRemote() async {
    final userId = _userId;
    if (userId == null) return;
    final snapshot = await ref
        .read(preferenceSyncServiceProvider)
        .synchronize(userId: userId, scope: musicVisualizerPreferenceScope);
    if (_userId != userId) return;
    state = AsyncData(
      snapshot.preferences.isEmpty
          ? const PortalMusicVisualizerPreferences()
          : PortalMusicVisualizerPreferences.fromJson(snapshot.preferences),
    );
  }

  Future<void> _save(PortalMusicVisualizerPreferences preferences) async {
    state = AsyncData(preferences);
    final userId = _userId;
    if (userId == null) {
      return;
    }
    final snapshot = await ref
        .read(preferenceSyncServiceProvider)
        .patch(
          userId: userId,
          scope: musicVisualizerPreferenceScope,
          changes: preferences.toJson(),
        );
    state = AsyncData(
      PortalMusicVisualizerPreferences.fromJson(snapshot.preferences),
    );
  }

  Future<PortalMusicVisualizerPreferences> _loadLegacyLocal() async {
    final preferences = await SharedPreferences.getInstance();
    final raw =
        preferences.getString(_legacyLocalKey) ??
        preferences.getString(_olderLegacyLocalKey);
    if (raw == null || raw.isEmpty) {
      return const PortalMusicVisualizerPreferences();
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? PortalMusicVisualizerPreferences.fromJson(decoded)
          : const PortalMusicVisualizerPreferences();
    } on FormatException {
      return const PortalMusicVisualizerPreferences();
    }
  }

  Future<void> _clearLegacyLocal() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacyLocalKey);
    await preferences.remove(_olderLegacyLocalKey);
  }
}
