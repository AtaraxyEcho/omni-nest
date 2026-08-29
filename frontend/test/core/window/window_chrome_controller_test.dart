import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/core/window/window_chrome_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('toggleFullscreen toggles manual fullscreen state', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(windowChromeControllerProvider.notifier);

    await controller.toggleFullscreen();
    expect(container.read(windowChromeControllerProvider).isFullscreen, isTrue);

    await controller.toggleFullscreen();
    expect(
      container.read(windowChromeControllerProvider).isFullscreen,
      isFalse,
    );
  });

  test('toggleFullscreen exits an active immersive owner', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(windowChromeControllerProvider.notifier);
    var exited = false;
    await controller.requestImmersive(
      owner: 'movie-player',
      onExit: () => exited = true,
    );

    await controller.toggleFullscreen();

    expect(exited, isTrue);
    expect(
      container.read(windowChromeControllerProvider).immersiveOwner,
      isNull,
    );
    expect(
      container.read(windowChromeControllerProvider).isFullscreen,
      isFalse,
    );
  });

  test('releasing an older lease keeps the newer owner active', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(windowChromeControllerProvider.notifier);

    final older = controller.acquireImmersive(owner: 'reader');
    final newer = controller.acquireImmersive(owner: 'photos');
    older.release();

    final active = container.read(windowChromeControllerProvider);
    expect(active.immersiveOwner, 'photos');
    expect(active.isFullscreen, isTrue);

    newer.release();
    expect(
      container.read(windowChromeControllerProvider).isFullscreen,
      isFalse,
    );
  });

  test('lease release is idempotent and preserves manual fullscreen', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final controller = container.read(windowChromeControllerProvider.notifier);
    await controller.setFullscreen(true);
    final lease = controller.acquireFullscreen(owner: 'movie');

    lease
      ..release()
      ..release();

    expect(container.read(windowChromeControllerProvider).isFullscreen, isTrue);
    await controller.setFullscreen(false);
    expect(
      container.read(windowChromeControllerProvider).isFullscreen,
      isFalse,
    );
  });

  test(
    'rapid immersive enter and exit leaves native window restored',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('omninest/window_frame');
      final fullscreenEntered = Completer<void>();
      final allowFullscreenEnter = Completer<void>();
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'setWindowFullscreen') {
              final fullscreen =
                  (call.arguments as Map<Object?, Object?>)['fullscreen']
                      as bool;
              calls.add('fullscreen:$fullscreen');
              if (fullscreen) {
                fullscreenEntered.complete();
                await allowFullscreenEnter.future;
              }
            } else {
              calls.add(call.method);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        windowChromeControllerProvider.notifier,
      );

      final lease = controller.acquireImmersive(owner: 'reader');
      await fullscreenEntered.future;
      lease.release();
      allowFullscreenEnter.complete();
      await controller.pendingApply;

      expect(
        calls.where((call) => call.startsWith('fullscreen:')).last,
        'fullscreen:false',
      );
      expect(calls, contains('restoreWindowPlacement'));
      expect(
        container.read(windowChromeControllerProvider).chromeHidden,
        isFalse,
      );
    },
  );
}
