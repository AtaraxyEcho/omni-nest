import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/providers.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/features/portal/domain/portal_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

final portalPreferencesProvider =
    AsyncNotifierProvider<PortalPreferencesNotifier, PortalPreferences>(
      PortalPreferencesNotifier.new,
    );

class PortalPreferencesNotifier extends AsyncNotifier<PortalPreferences> {
  static const _scope = 'portal';
  static const _legacyLocalVisualFamilyKey = 'portal_visual_family';
  static const _legacyLocalStyleKey = 'portal_desktop_style';
  static const _legacyLocalWeatherEffectsKey = 'portal_weather_effects_enabled';
  static const _legacyLocalImmersiveModeKey = 'portal_immersive_mode_enabled';
  static const _obsoleteRemoteKeys = <String>{
    'visualFamily',
    'desktopStyle',
    'weatherEffectsEnabled',
    'styleVersion',
  };

  String? _userId;

  @override
  Future<PortalPreferences> build() async {
    final legacy = await _loadLegacyLocal();
    final session = await ref.watch(authSessionProvider.future);
    _userId = session.user?.id;
    final userId = _userId;
    if (userId == null) {
      return legacy;
    }
    final snapshot = await ref
        .read(preferenceSyncServiceProvider)
        .load(userId: userId, scope: _scope);
    if (snapshot.preferences.isNotEmpty) {
      await _clearLegacyLocal();
      final resolved = PortalPreferences.fromJson(snapshot.preferences);
      final hasObsoletePreferences = snapshot.preferences.keys.any(
        _obsoleteRemoteKeys.contains,
      );
      if (!hasObsoletePreferences) {
        return resolved;
      }
      final migrated = await ref
          .read(preferenceSyncServiceProvider)
          .patch(
            userId: userId,
            scope: _scope,
            changes: resolved.toJson()..['schemaVersion'] = 2,
            removeKeys: _obsoleteRemoteKeys,
          );
      return PortalPreferences.fromJson(migrated.preferences);
    }
    final migrated = await ref
        .read(preferenceSyncServiceProvider)
        .patch(
          userId: userId,
          scope: _scope,
          changes: legacy.toJson()..['schemaVersion'] = 2,
          removeKeys: _obsoleteRemoteKeys,
        );
    await _clearLegacyLocal();
    return PortalPreferences.fromJson(migrated.preferences);
  }

  Future<void> updateImmersiveMode(bool enabled) async {
    final current = state.asData?.value ?? const PortalPreferences();
    await _save(current.copyWith(immersiveModeEnabled: enabled));
  }

  /// 从远端重新同步 Portal 偏好，并保留本地待提交变更。
  Future<void> refreshFromRemote() async {
    final userId = _userId;
    if (userId == null) return;
    final snapshot = await ref
        .read(preferenceSyncServiceProvider)
        .synchronize(userId: userId, scope: _scope);
    if (_userId != userId) return;
    state = AsyncData(
      snapshot.preferences.isEmpty
          ? const PortalPreferences()
          : PortalPreferences.fromJson(snapshot.preferences),
    );
  }

  Future<void> _save(PortalPreferences preferences) async {
    state = AsyncData(preferences);
    final userId = _userId;
    if (userId == null) {
      return;
    }
    final snapshot = await ref
        .read(preferenceSyncServiceProvider)
        .patch(
          userId: userId,
          scope: _scope,
          changes: preferences.toJson()..['schemaVersion'] = 2,
          removeKeys: _obsoleteRemoteKeys,
        );
    state = AsyncData(PortalPreferences.fromJson(snapshot.preferences));
  }

  Future<PortalPreferences> _loadLegacyLocal() async {
    final preferences = await SharedPreferences.getInstance();
    return PortalPreferences(
      immersiveModeEnabled:
          preferences.getBool(_legacyLocalImmersiveModeKey) ?? false,
    );
  }

  Future<void> _clearLegacyLocal() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_legacyLocalVisualFamilyKey);
    await preferences.remove(_legacyLocalStyleKey);
    await preferences.remove(_legacyLocalWeatherEffectsKey);
    await preferences.remove(_legacyLocalImmersiveModeKey);
  }
}
