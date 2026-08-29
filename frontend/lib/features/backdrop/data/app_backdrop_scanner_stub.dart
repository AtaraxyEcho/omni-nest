import 'package:omninest/features/backdrop/domain/app_backdrop.dart';

/// 非本机文件平台使用的应用背景扫描器存根。
class AppBackdropScanner {
  /// 从本机文件路径构建背景素材。
  Future<List<AppBackdropAsset>> fromFiles(
    List<String> paths, {
    AppBackdropSourceType sourceType = AppBackdropSourceType.file,
    String? sourceDirectory,
  }) async {
    return const <AppBackdropAsset>[];
  }

  /// 扫描本机目录。
  Future<List<AppBackdropAsset>> scanDirectory(String directoryPath) async {
    return const <AppBackdropAsset>[];
  }

  /// 检测文件缺失状态。
  Future<Map<String, bool>> detectMissing(
    List<AppBackdropAsset> backdrops,
  ) async {
    return const <String, bool>{};
  }
}
