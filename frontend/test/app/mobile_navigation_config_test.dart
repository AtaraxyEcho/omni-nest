import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/mobile_shell/mobile_navigation_config.dart';
import 'package:omninest/features/backdrop/domain/app_backdrop_policy.dart';

void main() {
  group('MobileNavigationConfig', () {
    test('将照片与影视映射到独立入口', () {
      expect(
        MobileNavigationConfig.destinationIndexForBranch(
          MobileNavigationConfig.photosBranch,
        ),
        3,
      );
      expect(
        MobileNavigationConfig.destinationIndexForBranch(
          MobileNavigationConfig.videoBranch,
        ),
        4,
      );
    });

    test('一级导航项直接映射对应分支', () {
      expect(
        MobileNavigationConfig.branchForDestination(3),
        MobileNavigationConfig.photosBranch,
      );
      expect(
        MobileNavigationConfig.branchForDestination(4),
        MobileNavigationConfig.videoBranch,
      );
    });

    test('模块搜索范围保持独立', () {
      expect(
        MobileNavigationConfig.searchScopeForBranch(
          MobileNavigationConfig.filesBranch,
        ),
        'files',
      );
      expect(
        MobileNavigationConfig.searchScopeForBranch(
          MobileNavigationConfig.videoBranch,
        ),
        'video',
      );
      expect(
        MobileNavigationConfig.searchScopeForBranch(
          MobileNavigationConfig.portalBranch,
        ),
        'all',
      );
    });

    test('移动端业务模块统一使用连续动态背景策略', () {
      expect(
        MobileNavigationConfig.backdropPolicyForBranch(
          MobileNavigationConfig.portalBranch,
        ),
        AppBackdropPolicy.portalMobile,
      );
      expect(
        AppBackdropPolicy.portalMobile.readabilityMode,
        AppBackdropReadabilityMode.none,
      );
      expect(
        MobileNavigationConfig.backdropPolicyForBranch(
          MobileNavigationConfig.filesBranch,
        ),
        AppBackdropPolicy.mobileContent,
      );
      expect(
        MobileNavigationConfig.backdropPolicyForBranch(
          MobileNavigationConfig.musicBranch,
        ),
        AppBackdropPolicy.musicDeck,
      );
      expect(
        MobileNavigationConfig.backdropPolicyForBranch(
          MobileNavigationConfig.readerBranch,
        ),
        AppBackdropPolicy.mobileContent,
      );
      for (final branch in <int>[
        MobileNavigationConfig.filesBranch,
        MobileNavigationConfig.photosBranch,
        MobileNavigationConfig.videoBranch,
        MobileNavigationConfig.readerBranch,
      ]) {
        final policy = MobileNavigationConfig.backdropPolicyForBranch(branch);
        expect(policy.playbackMode, AppBackdropPlaybackMode.continuous);
        expect(policy.motionAllowed, isTrue);
        expect(policy.readabilityMode, AppBackdropReadabilityMode.none);
      }
    });
  });
}
