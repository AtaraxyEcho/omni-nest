import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/providers.dart';
import 'package:omninest/core/auth/auth_controller.dart';
import 'package:omninest/core/realtime/realtime_api.dart';
import 'package:omninest/core/realtime/realtime_coordinator.dart';
import 'package:omninest/core/realtime/realtime_models.dart';
import 'package:omninest/core/realtime/realtime_stomp_client.dart';
import 'package:omninest/core/realtime/realtime_store.dart';
import 'package:omninest/core/storage/local_database_provider.dart';

/// 当前登录用户的全平台实时同步协调器。
final realtimeCoordinatorProvider = Provider<RealtimeCoordinator?>((ref) {
  final auth = ref.watch(authSessionProvider).asData?.value;
  if (auth == null || !auth.isAuthenticated || auth.user == null) {
    return null;
  }
  final apiClient = ref.watch(apiClientProvider);
  final accessToken = apiClient.currentAccessToken();
  if (accessToken == null || accessToken.isEmpty) {
    return null;
  }

  final environment = ref.watch(appEnvironmentProvider);
  final platform = defaultTargetPlatform;
  final isMobile =
      !kIsWeb &&
      (platform == TargetPlatform.android || platform == TargetPlatform.iOS);
  final store = RealtimeStore(
    database: ref.watch(localDatabaseProvider),
    serverKey: _serverKey(environment.apiBaseUrl),
    userId: auth.user!.id,
  );
  final client = RealtimeStompClient(
    url: '${_withoutTrailingSlash(environment.wsBaseUrl)}/realtime',
    accessToken: accessToken,
  );
  final coordinator = RealtimeCoordinator(
    api: RealtimeApi(apiClient),
    store: store,
    stompClient: client,
    connectivity: ref.watch(connectivityListenerProvider).onlineStream,
    refreshSession:
        () => ref.read(authSessionProvider.notifier).refreshSession(),
    suspendInBackground: isMobile,
    headInterval:
        isMobile ? const Duration(minutes: 5) : const Duration(minutes: 2),
  );
  unawaited(coordinator.start());
  ref.onDispose(() => unawaited(coordinator.dispose()));
  return coordinator;
});

/// 当前实时同步状态。
final realtimePhaseProvider = StreamProvider<RealtimePhase>((ref) async* {
  final coordinator = ref.watch(realtimeCoordinatorProvider);
  if (coordinator == null) {
    yield RealtimePhase.signedOut;
    return;
  }
  yield coordinator.phase;
  yield* coordinator.phases;
});

String _serverKey(String apiBaseUrl) {
  return _withoutTrailingSlash(apiBaseUrl).toLowerCase();
}

String _withoutTrailingSlash(String value) {
  return value.replaceFirst(RegExp(r'/+$'), '');
}
