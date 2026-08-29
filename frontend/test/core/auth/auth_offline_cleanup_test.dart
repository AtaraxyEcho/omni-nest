import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/auth/auth_models.dart';
import 'package:omninest/core/auth/auth_session_store_base.dart';
import 'package:omninest/core/security/offline_data_lifecycle_base.dart';
import 'package:omninest/core/security/offline_memory_cache.dart';

void main() {
  test('退出登录会清理当前用户离线数据和认证存储', () async {
    final sessionStore = _RecordingSessionStore();
    final lifecycle = _RecordingOfflineDataLifecycle();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
        authSessionStoreProvider.overrideWithValue(sessionStore),
        offlineDataLifecycleProvider.overrideWithValue(lifecycle),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authSessionProvider.future);
    OfflineMemoryCache.write(
      userId: 'user-1',
      cacheType: 'reader-book',
      businessId: 'item-1',
      bytes: Uint8List.fromList(<int>[1, 2, 3]),
    );

    await container.read(authSessionProvider.notifier).clearSession();

    expect(lifecycle.clearedUserId, 'user-1');
    expect(sessionStore.cleared, isTrue);
    expect(
      OfflineMemoryCache.read(
        userId: 'user-1',
        cacheType: 'reader-book',
        businessId: 'item-1',
      ),
      isNull,
    );
    expect(
      container.read(authSessionProvider).requireValue.isAuthenticated,
      isFalse,
    );
  });

  test('离线数据清理失败时仍会清除认证会话', () async {
    final sessionStore = _RecordingSessionStore();
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
        authSessionStoreProvider.overrideWithValue(sessionStore),
        offlineDataLifecycleProvider.overrideWithValue(
          _RecordingOfflineDataLifecycle(shouldFail: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(authSessionProvider.future);

    await container.read(authSessionProvider.notifier).clearSession();

    expect(sessionStore.cleared, isTrue);
    expect(
      container.read(authSessionProvider).requireValue.isAuthenticated,
      isFalse,
    );
  });
}

class _AuthenticatedSessionNotifier extends AuthSessionNotifier {
  @override
  Future<AuthSessionState> build() async {
    return AuthSessionState(
      user: UserProfile(id: 'user-1', username: 'reader', role: 'MEMBER'),
    );
  }
}

class _RecordingSessionStore implements AuthSessionStore {
  bool cleared = false;

  @override
  Future<void> clear() async {
    cleared = true;
  }

  @override
  String? readAccessToken() => null;

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> saveAccessToken(String? accessToken) async {}

  @override
  Future<void> saveSession(AuthTokenResponse session) async {}
}

class _RecordingOfflineDataLifecycle implements OfflineDataLifecycle {
  _RecordingOfflineDataLifecycle({this.shouldFail = false});

  final bool shouldFail;
  String? clearedUserId;

  @override
  Future<void> clearUser(String userId) async {
    clearedUserId = userId;
    OfflineMemoryCache.clearUser(userId);
    if (shouldFail) {
      throw const FormatException('测试清理失败');
    }
  }
}
