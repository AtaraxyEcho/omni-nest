import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/core/storage/local_database_provider.dart';
import 'package:omninest/core/utils/platform_helper.dart';
import 'package:omninest/features/backdrop/data/app_backdrop_bundled_asset.dart';
import 'package:omninest/features/backdrop/data/app_backdrop_repository.dart';
import 'package:omninest/features/backdrop/data/app_backdrop_scanner.dart';
import 'package:omninest/features/backdrop/domain/app_backdrop.dart';

final appBackdropRepositoryProvider = Provider<AppBackdropRepository>((ref) {
  return AppBackdropRepository(ref.watch(localDatabaseProvider));
});

final appBackdropBundledAssetInstallerProvider =
    Provider<AppBackdropBundledAssetInstaller>((ref) {
      return AppBackdropBundledAssetInstaller();
    });

final appBackdropSelectionTargetProvider = Provider<AppBackdropSelectionTarget>(
  (ref) =>
      isMobilePlatform
          ? AppBackdropSelectionTarget.mobile
          : AppBackdropSelectionTarget.desktop,
);

final appBackdropControllerProvider =
    AsyncNotifierProvider<AppBackdropController, AppBackdropState>(
      AppBackdropController.new,
    );

/// 应用本机背景库控制器。
class AppBackdropController extends AsyncNotifier<AppBackdropState> {
  late final AppBackdropRepository _repository;
  final AppBackdropScanner _scanner = AppBackdropScanner();

  @override
  Future<AppBackdropState> build() async {
    _repository = ref.watch(appBackdropRepositoryProvider);
    ref.watch(appBackdropSelectionTargetProvider);
    if (!isWebPlatform) {
      try {
        final bundledAsset =
            await ref.read(appBackdropBundledAssetInstallerProvider).install();
        if (bundledAsset != null) {
          await _repository.ensureBundledBackdrop(bundledAsset);
        }
      } on Object catch (error, stackTrace) {
        if (kDebugMode) {
          debugPrint('应用内置背景安装失败: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
    }
    final state = await _loadCurrentState();
    if (!isWebPlatform) {
      await _refreshMissing(state.backdrops);
      return _loadCurrentState();
    }
    return state;
  }

  /// 添加本机背景文件。
  Future<void> addFiles() async {
    if (isWebPlatform) {
      return;
    }
    final FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const <String>[
          'jpg',
          'jpeg',
          'png',
          'webp',
          'gif',
          'mp4',
          'webm',
          'mov',
          'm4v',
        ],
        withData: false,
      );
    } on Object catch (error, stackTrace) {
      await _setScanFailed(error, stackTrace);
      return;
    }
    final paths =
        result?.files
            .map((file) => file.path)
            .whereType<String>()
            .toList(growable: false) ??
        const <String>[];
    if (paths.isEmpty) {
      return;
    }
    await _addPaths(paths);
  }

  /// 扫描本机背景目录。
  Future<void> scanDirectory() async {
    if (!isDesktopPlatform) {
      return;
    }
    final String? directory;
    try {
      directory = await FilePicker.platform.getDirectoryPath();
    } on Object catch (error, stackTrace) {
      await _setScanFailed(error, stackTrace);
      return;
    }
    if (directory == null || directory.isEmpty) {
      return;
    }
    await scanDirectoryPath(directory);
  }

  /// 扫描指定本机目录并导入背景素材。
  Future<void> scanDirectoryPath(String directory) async {
    final selectedDirectory = directory.trim();
    if (selectedDirectory.isEmpty) {
      return;
    }
    await _runScan(() => _scanner.scanDirectory(selectedDirectory));
  }

  /// 选择本机背景。
  Future<void> selectBackdrop(String id) async {
    final current = state.asData?.value ?? await _loadCurrentState();
    final selected = current.backdrops.where((backdrop) => backdrop.id == id);
    if (selected.isEmpty) {
      return;
    }
    final updated = current.settings.selectBackdropFor(
      current.selectionTarget,
      id,
    );
    await _repository.saveSettings(updated);
    state = AsyncData(await _loadCurrentState());
  }

  /// 设置桌面端和移动端是否分别保存背景选择。
  Future<void> setDeviceSeparation(bool separate) async {
    final current = state.asData?.value ?? await _loadCurrentState();
    final updated = current.settings.withDeviceSeparation(
      separate,
      current.selectionTarget,
    );
    await _repository.saveSettings(updated);
    state = AsyncData(await _loadCurrentState());
  }

  /// 启用或关闭本机背景。
  Future<void> setEnabled(bool enabled) async {
    final current = state.asData?.value ?? await _loadCurrentState();
    final nextEnabled = enabled && current.selectedBackdrop != null;
    await _repository.saveSettings(
      current.settings.copyWith(enabled: nextEnabled),
    );
    state = AsyncData(await _loadCurrentState());
  }

  /// 更新背景适配方式。
  Future<void> setFit(AppBackdropFit fit) async {
    final current = state.asData?.value ?? await _loadCurrentState();
    await _repository.saveSettings(current.settings.copyWith(fit: fit));
    state = AsyncData(await _loadCurrentState());
  }

  /// 更新背景暗化强度。
  Future<void> setDimAmount(double value) async {
    final current = state.asData?.value ?? await _loadCurrentState();
    await _repository.saveSettings(current.settings.copyWith(dimAmount: value));
    state = AsyncData(await _loadCurrentState());
  }

  /// 更新背景模糊强度。
  Future<void> setBlurAmount(double value) async {
    final current = state.asData?.value ?? await _loadCurrentState();
    await _repository.saveSettings(
      current.settings.copyWith(blurAmount: value),
    );
    state = AsyncData(await _loadCurrentState());
  }

  /// 更新视频静音设置。
  Future<void> setVideoMuted(bool muted) async {
    final current = state.asData?.value ?? await _loadCurrentState();
    await _repository.saveSettings(
      current.settings.copyWith(videoMuted: muted),
    );
    state = AsyncData(await _loadCurrentState());
  }

  /// 移除本机背景。
  Future<void> removeBackdrop(String id) async {
    final current = state.asData?.value ?? await _loadCurrentState();
    final selected = current.backdrops.where((backdrop) => backdrop.id == id);
    if (selected.any((backdrop) => backdrop.isBundled)) {
      return;
    }
    await _repository.removeBackdrop(id);
    state = AsyncData(await _loadCurrentState());
  }

  /// 清空本机背景库。
  Future<void> clearBackdrops() async {
    await _repository.clearBackdrops();
    state = AsyncData(await _loadCurrentState());
  }

  Future<void> _addPaths(List<String> paths) async {
    await _runScan(() => _scanner.fromFiles(paths));
  }

  Future<void> _runScan(Future<List<AppBackdropAsset>> Function() scan) async {
    final current = state.asData?.value ?? await _loadCurrentState();
    state = AsyncData(current.copyWith(isScanning: true, clearMessage: true));
    try {
      final backdrops = await scan();
      await _repository.upsertBackdrops(backdrops);
      // 扫描只更新素材库，避免未确认的视频在扫描完成时立即创建原生纹理。
      state = AsyncData(
        (await _loadCurrentState()).copyWith(
          message: backdrops.isEmpty ? AppBackdropMessage.emptyScan : null,
        ),
      );
    } on Object catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('应用本机背景扫描失败: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
      state = AsyncData(
        current.copyWith(
          isScanning: false,
          message: AppBackdropMessage.scanFailed,
        ),
      );
    }
  }

  Future<void> _setScanFailed(Object error, StackTrace stackTrace) async {
    final current = state.asData?.value ?? await _loadCurrentState();
    if (kDebugMode) {
      debugPrint('应用本机背景文件选择失败: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    state = AsyncData(
      current.copyWith(
        isScanning: false,
        message: AppBackdropMessage.scanFailed,
      ),
    );
  }

  Future<void> _refreshMissing(List<AppBackdropAsset> backdrops) async {
    if (backdrops.isEmpty) {
      return;
    }
    final missing = await _scanner.detectMissing(backdrops);
    await _repository.updateMissing(missing);
  }

  Future<AppBackdropState> _loadCurrentState() async {
    final loaded = await _repository.loadState();
    return loaded.copyWith(
      selectionTarget: ref.read(appBackdropSelectionTargetProvider),
    );
  }
}
