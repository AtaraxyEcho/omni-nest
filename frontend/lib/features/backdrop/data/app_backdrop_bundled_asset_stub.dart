import 'package:omninest/features/backdrop/domain/app_backdrop.dart';

/// Web 平台不安装本机背景资源。
class AppBackdropBundledAssetInstaller {
  /// Web 平台返回空结果。
  Future<AppBackdropAsset?> install() async => null;
}
