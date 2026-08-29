import 'package:omninest/features/backdrop/domain/app_backdrop_policy.dart';

/// 移动端一级导航与路由分支之间的稳定映射。
class MobileNavigationConfig {
  const MobileNavigationConfig._();

  static const int portalBranch = 0;
  static const int filesBranch = 1;
  static const int musicBranch = 2;
  static const int photosBranch = 3;
  static const int videoBranch = 4;
  static const int readerBranch = 5;

  /// 将六个持久化路由分支映射为六个一级导航项。
  static int destinationIndexForBranch(int branch) {
    return switch (branch) {
      >= portalBranch && <= readerBranch => branch,
      _ => portalBranch,
    };
  }

  /// 将六个一级导航项映射为对应的持久化路由分支。
  static int branchForDestination(int destination) {
    return switch (destination) {
      >= portalBranch && <= readerBranch => destination,
      _ => readerBranch,
    };
  }

  /// 返回当前模块的全局搜索范围。
  static String searchScopeForBranch(int branch) {
    return switch (branch) {
      filesBranch => 'files',
      musicBranch => 'music',
      photosBranch => 'photos',
      videoBranch => 'video',
      readerBranch => 'reader',
      _ => 'all',
    };
  }

  /// 返回当前分支默认使用的应用背景策略。
  static AppBackdropPolicy backdropPolicyForBranch(int branch) {
    return switch (branch) {
      portalBranch => AppBackdropPolicy.portalMobile,
      musicBranch => AppBackdropPolicy.musicDeck,
      filesBranch ||
      photosBranch ||
      videoBranch ||
      readerBranch => AppBackdropPolicy.mobileContent,
      _ => AppBackdropPolicy.work,
    };
  }
}
