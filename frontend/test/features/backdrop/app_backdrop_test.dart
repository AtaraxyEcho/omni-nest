import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/core/storage/local_database.dart';
import 'package:omninest/features/backdrop/application/app_backdrop_controller.dart';
import 'package:omninest/features/backdrop/application/app_backdrop_scene_controller.dart';
import 'package:omninest/features/backdrop/application/app_backdrop_video_session.dart';
import 'package:omninest/features/backdrop/data/app_backdrop_bundled_asset.dart';
import 'package:omninest/features/backdrop/data/app_backdrop_repository.dart';
import 'package:omninest/features/backdrop/data/app_backdrop_scanner.dart';
import 'package:omninest/features/backdrop/domain/app_backdrop.dart';
import 'package:omninest/features/backdrop/domain/app_backdrop_policy.dart';
import 'package:omninest/features/backdrop/presentation/app_backdrop_scene_scope.dart';

void main() {
  group('AppBackdropState', () {
    final first = AppBackdropAsset(
      id: 'first',
      path: 'D:/Media/first.jpg',
      title: 'first',
      mediaType: AppBackdropMediaType.image,
      sourceType: AppBackdropSourceType.file,
      fileSize: 1024,
      modifiedAt: DateTime(2026),
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    final second = first.copyWith(id: 'second', path: 'D:/Media/second.mp4');

    test('没有显式选择时不返回背景', () {
      final state = AppBackdropState(backdrops: [first, second]);

      expect(state.selectedBackdrop, isNull);
    });

    test('显式选择存在时优先使用对应背景', () {
      final state = AppBackdropState(
        backdrops: [first, second],
        settings: const AppBackdropSettings(selectedBackdropId: 'second'),
      );

      expect(state.selectedBackdrop, second);
    });

    test('显式选择不存在时不返回背景', () {
      final state = AppBackdropState(
        backdrops: [first, second],
        settings: const AppBackdropSettings(selectedBackdropId: 'missing'),
      );

      expect(state.selectedBackdrop, isNull);
    });

    test('空素材库不返回背景', () {
      const state = AppBackdropState();

      expect(state.selectedBackdrop, isNull);
      expect(state.hasActiveBackdrop, isFalse);
    });

    test('仅在素材存在且显式启用时返回活动状态', () {
      final disabled = AppBackdropState(
        backdrops: [first],
        settings: const AppBackdropSettings(selectedBackdropId: 'first'),
      );
      final enabled = AppBackdropState(
        backdrops: [first],
        settings: const AppBackdropSettings(
          enabled: true,
          selectedBackdropId: 'first',
        ),
      );

      expect(disabled.hasActiveBackdrop, isFalse);
      expect(enabled.hasActiveBackdrop, isTrue);
    });

    test('隔离开启后按设备类别返回对应背景', () {
      final settings = const AppBackdropSettings(
        enabled: true,
        separateDeviceBackdrops: true,
        desktopBackdropId: 'first',
        mobileBackdropId: 'second',
      );
      final desktop = AppBackdropState(
        backdrops: [first, second],
        settings: settings,
      );
      final mobile = desktop.copyWith(
        selectionTarget: AppBackdropSelectionTarget.mobile,
      );

      expect(desktop.selectedBackdrop, first);
      expect(mobile.selectedBackdrop, second);
      expect(desktop.hasActiveBackdrop, isTrue);
      expect(mobile.hasActiveBackdrop, isTrue);
    });
  });

  group('AppBackdropSettings', () {
    test('开启隔离时从共享选择初始化两端槽位', () {
      const settings = AppBackdropSettings(selectedBackdropId: 'shared');

      final separated = settings.withDeviceSeparation(
        true,
        AppBackdropSelectionTarget.desktop,
      );

      expect(separated.separateDeviceBackdrops, isTrue);
      expect(separated.desktopBackdropId, 'shared');
      expect(separated.mobileBackdropId, 'shared');
    });

    test('关闭后再次开启隔离会保留两端历史选择', () {
      const settings = AppBackdropSettings(
        selectedBackdropId: 'shared',
        separateDeviceBackdrops: true,
        desktopBackdropId: 'desktop',
        mobileBackdropId: 'mobile',
      );

      final shared = settings.withDeviceSeparation(
        false,
        AppBackdropSelectionTarget.desktop,
      );
      final restored = shared.withDeviceSeparation(
        true,
        AppBackdropSelectionTarget.desktop,
      );

      expect(shared.selectedBackdropId, 'desktop');
      expect(restored.desktopBackdropId, 'desktop');
      expect(restored.mobileBackdropId, 'mobile');
    });
  });

  group('AppBackdropRepository bundled asset', () {
    test('默认动态壁纸已打包进 Flutter 资源', () async {
      final data = await rootBundle.load(
        'assets/backdrops/default_wallpaper.mp4',
      );

      expect(data.lengthInBytes, 5950165);
    });

    test('首次安装内置壁纸时默认启用且后续安装不覆盖用户设置', () async {
      final database = LocalDatabase(NativeDatabase.memory());
      final repository = AppBackdropRepository(database);
      addTearDown(database.close);
      final bundled = _backdrop(
        'bundled',
        'D:/App/backdrops/default.mp4',
      ).copyWith(
        mediaType: AppBackdropMediaType.video,
        sourceType: AppBackdropSourceType.bundled,
      );

      await repository.ensureBundledBackdrop(bundled);
      final initial = await repository.loadState();

      expect(initial.settings.enabled, isTrue);
      expect(initial.selectedBackdrop?.id, bundled.id);

      final custom = _backdrop('custom', 'D:/Media/custom.jpg');
      await repository.upsertBackdrops([custom]);

      await repository.saveSettings(
        const AppBackdropSettings(enabled: false, selectedBackdropId: 'custom'),
      );
      await repository.ensureBundledBackdrop(bundled);
      final preserved = await repository.loadState();

      expect(preserved.settings.enabled, isFalse);
      expect(preserved.settings.selectedBackdropId, custom.id);
    });

    test('删除和清空操作保留内置壁纸', () async {
      final database = LocalDatabase(NativeDatabase.memory());
      final repository = AppBackdropRepository(database);
      addTearDown(database.close);
      final bundled = _backdrop(
        'bundled',
        'D:/App/backdrops/default.mp4',
      ).copyWith(
        mediaType: AppBackdropMediaType.video,
        sourceType: AppBackdropSourceType.bundled,
      );
      final custom = _backdrop('custom', 'D:/Media/custom.jpg');
      await repository.ensureBundledBackdrop(bundled);
      await repository.upsertBackdrops([custom]);

      await repository.removeBackdrop(bundled.id);
      expect((await repository.loadState()).backdrops, hasLength(2));

      await repository.clearBackdrops();
      final cleared = await repository.loadState();
      expect(cleared.backdrops, hasLength(1));
      expect(cleared.backdrops.single.id, bundled.id);
      expect(cleared.settings.selectedBackdropId, bundled.id);
    });
  });

  group('AppBackdropScanner', () {
    test('同目录 preview 文件只作为卡片预览，不作为背景入库', () async {
      final directory = await Directory.systemTemp.createTemp(
        'portal_backdrop_',
      );
      addTearDown(() async {
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });
      final preview = File(
        '${directory.path}${Platform.pathSeparator}preview.gif',
      );
      final video = File('${directory.path}${Platform.pathSeparator}scene.mp4');
      await preview.writeAsBytes([0x47, 0x49, 0x46]);
      await video.writeAsBytes([0x00, 0x00, 0x00, 0x18]);

      final scanner = AppBackdropScanner();
      final backdrops = await scanner.scanDirectory(directory.path);

      expect(backdrops, hasLength(1));
      expect(backdrops.single.path, video.path);
      expect(backdrops.single.thumbnailPath, preview.path);
      expect(backdrops.single.mediaType, AppBackdropMediaType.video);
    });
  });

  group('AppBackdropController', () {
    test('扫描视频目录只导入素材且选择操作不隐式启用播放', () async {
      final directory = await Directory.systemTemp.createTemp(
        'portal_backdrop_controller_',
      );
      final video = File('${directory.path}${Platform.pathSeparator}scene.mp4');
      await video.writeAsBytes([0x00, 0x00, 0x00, 0x18]);
      final database = LocalDatabase(NativeDatabase.memory());
      final repository = AppBackdropRepository(database);
      final container = ProviderContainer.test(
        overrides: [
          appBackdropRepositoryProvider.overrideWithValue(repository),
          appBackdropBundledAssetInstallerProvider.overrideWithValue(
            _NoopBundledAssetInstaller(),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      await container.read(appBackdropControllerProvider.future);
      final notifier = container.read(appBackdropControllerProvider.notifier);
      await notifier.scanDirectoryPath(directory.path);

      final imported =
          container.read(appBackdropControllerProvider).requireValue;
      expect(imported.backdrops, hasLength(1));
      expect(imported.settings.selectedBackdropId, isNull);
      expect(imported.hasActiveBackdrop, isFalse);

      await notifier.selectBackdrop(imported.backdrops.single.id);

      final selected =
          container.read(appBackdropControllerProvider).requireValue;
      expect(
        selected.settings.selectedBackdropId,
        imported.backdrops.single.id,
      );
      expect(selected.settings.enabled, isFalse);
      expect(selected.hasActiveBackdrop, isFalse);
    });

    test('桌面端改选隔离壁纸不会覆盖移动端槽位', () async {
      final directory = await Directory.systemTemp.createTemp(
        'portal_backdrop_separation_',
      );
      final desktopFile = File(
        '${directory.path}${Platform.pathSeparator}desktop.jpg',
      );
      final mobileFile = File(
        '${directory.path}${Platform.pathSeparator}mobile.jpg',
      );
      await desktopFile.writeAsBytes([0xFF, 0xD8, 0xFF]);
      await mobileFile.writeAsBytes([0xFF, 0xD8, 0xFF]);
      final database = LocalDatabase(NativeDatabase.memory());
      final repository = AppBackdropRepository(database);
      final desktopBackdrop = _backdrop('desktop', desktopFile.path);
      final mobileBackdrop = _backdrop('mobile', mobileFile.path);
      await repository.upsertBackdrops([desktopBackdrop, mobileBackdrop]);
      await repository.saveSettings(
        const AppBackdropSettings(selectedBackdropId: 'mobile'),
      );
      final desktopContainer = ProviderContainer.test(
        overrides: [
          appBackdropRepositoryProvider.overrideWithValue(repository),
          appBackdropBundledAssetInstallerProvider.overrideWithValue(
            _NoopBundledAssetInstaller(),
          ),
          appBackdropSelectionTargetProvider.overrideWithValue(
            AppBackdropSelectionTarget.desktop,
          ),
        ],
      );
      final mobileContainer = ProviderContainer.test(
        overrides: [
          appBackdropRepositoryProvider.overrideWithValue(repository),
          appBackdropBundledAssetInstallerProvider.overrideWithValue(
            _NoopBundledAssetInstaller(),
          ),
          appBackdropSelectionTargetProvider.overrideWithValue(
            AppBackdropSelectionTarget.mobile,
          ),
        ],
      );
      addTearDown(() async {
        desktopContainer.dispose();
        mobileContainer.dispose();
        await database.close();
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      });

      await desktopContainer.read(appBackdropControllerProvider.future);
      final notifier = desktopContainer.read(
        appBackdropControllerProvider.notifier,
      );
      await notifier.setDeviceSeparation(true);
      await notifier.selectBackdrop(desktopBackdrop.id);

      final state =
          desktopContainer.read(appBackdropControllerProvider).requireValue;
      expect(state.selectedBackdrop?.id, desktopBackdrop.id);
      expect(state.settings.desktopBackdropId, desktopBackdrop.id);
      expect(state.settings.mobileBackdropId, mobileBackdrop.id);

      final mobileState = await mobileContainer.read(
        appBackdropControllerProvider.future,
      );
      expect(mobileState.selectedBackdrop?.id, mobileBackdrop.id);
    });
  });

  group('AppBackdropSceneController', () {
    test('工作页面策略隐藏背景并启用工作可读性', () {
      expect(AppBackdropPolicy.work.scene, AppBackdropScene.work);
      expect(AppBackdropPolicy.work.visible, isFalse);
      expect(
        AppBackdropPolicy.work.playbackMode,
        AppBackdropPlaybackMode.paused,
      );
      expect(
        AppBackdropPolicy.work.readabilityMode,
        AppBackdropReadabilityMode.work,
      );
      expect(AppBackdropPolicy.work.motionAllowed, isFalse);
    });

    test('媒体内容页面使用静态背景快照', () {
      expect(AppBackdropPolicy.staticContent.visible, isTrue);
      expect(
        AppBackdropPolicy.staticContent.playbackMode,
        AppBackdropPlaybackMode.paused,
      );
      expect(AppBackdropPolicy.staticContent.motionAllowed, isFalse);
    });

    test('最近激活场景释放后回退到上一场景', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(
        appBackdropSceneControllerProvider.notifier,
      );

      controller.request('portal', AppBackdropPolicy.portal);
      controller.request('music', AppBackdropPolicy.musicDeck);

      expect(
        container.read(appBackdropSceneControllerProvider).policy.scene,
        AppBackdropScene.musicDeck,
      );

      controller.release('music');

      final state = container.read(appBackdropSceneControllerProvider);
      expect(state.owner, 'portal');
      expect(state.policy.scene, AppBackdropScene.portal);
    });

    test('过期租约不能释放同一所有者的新场景', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);
      final controller = container.read(
        appBackdropSceneControllerProvider.notifier,
      );

      final oldLease = controller.request('music', AppBackdropPolicy.portal);
      controller.request('music', AppBackdropPolicy.musicDeck);
      controller.release('music', lease: oldLease);

      final state = container.read(appBackdropSceneControllerProvider);
      expect(state.owner, 'music');
      expect(state.policy.scene, AppBackdropScene.musicDeck);
    });

    testWidgets('场景作用域卸载时在当前帧结束后释放场景', (tester) async {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppBackdropSceneScope(
              owner: 'music',
              policy: AppBackdropPolicy.musicDeck,
              child: SizedBox(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(container.read(appBackdropSceneControllerProvider).owner, 'music');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SizedBox()),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(container.read(appBackdropSceneControllerProvider).owner, isNull);
    });

    test('视频会话 Provider 在同一容器内保持单实例', () {
      final container = ProviderContainer.test();
      addTearDown(container.dispose);

      final first = container.read(appBackdropVideoSessionProvider);
      final second = container.read(appBackdropVideoSessionProvider);

      expect(identical(first, second), isTrue);
      expect(first.diagnostics.textureCount, 0);
      expect(first.diagnostics.successfulOpenCount, 0);
    });
  });
}

AppBackdropAsset _backdrop(String id, String path) {
  return AppBackdropAsset(
    id: id,
    path: path,
    title: id,
    mediaType: AppBackdropMediaType.image,
    sourceType: AppBackdropSourceType.file,
    fileSize: 1024,
    modifiedAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _NoopBundledAssetInstaller extends AppBackdropBundledAssetInstaller {
  @override
  Future<AppBackdropAsset?> install() async => null;
}
