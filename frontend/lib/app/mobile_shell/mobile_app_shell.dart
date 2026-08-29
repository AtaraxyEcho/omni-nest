import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/mobile_shell/mobile_navigation_config.dart';
import 'package:omninest/app/mobile_shell/mobile_shell_feature_bindings.dart';
import 'package:omninest/app/providers.dart';
import 'package:omninest/app/theme/feature/music_backdrop_theme.dart';
import 'package:omninest/app/theme/feature/music_colors.dart';
import 'package:omninest/app/theme/feature/portal_mobile_theme.dart';
import 'package:omninest/app/theme/mobile_app_theme.dart';
import 'package:omninest/app/theme/mobile_layout_tokens.dart';
import 'package:omninest/core/utils/platform_helper.dart';
import 'package:omninest/core/widgets/mobile_shell_scope.dart';
import 'package:omninest/core/widgets/mobile_ui.dart';
import 'package:omninest/core/widgets/module_switch_transition.dart';
import 'package:omninest/core/widgets/responsive_breakpoints.dart';
import 'package:omninest/core/widgets/user_avatar_menu.dart';
import 'package:omninest/features/backdrop/backdrop_ui.dart';
import 'package:omninest/features/music/music_shell_ui.dart';

/// 移动平台及紧凑视口使用的应用级导航壳层。
class MobileAppShell extends ConsumerStatefulWidget {
  const MobileAppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<MobileAppShell> createState() => _MobileAppShellState();
}

class _MobileAppShellState extends ConsumerState<MobileAppShell> {
  late int _previousBranch;
  bool _transitionForward = true;

  @override
  void initState() {
    super.initState();
    _previousBranch = widget.navigationShell.currentIndex;
  }

  @override
  void didUpdateWidget(covariant MobileAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final branch = widget.navigationShell.currentIndex;
    if (branch == _previousBranch) {
      return;
    }
    _transitionForward = branch > _previousBranch;
    _previousBranch = branch;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (!shouldUseResponsiveMobileShell(
      mobilePlatform: isMobilePlatform,
      width: width,
    )) {
      return MobileShellScope(hosted: false, child: _moduleContent());
    }
    final branch = widget.navigationShell.currentIndex;
    final useRail = width >= 840;
    final selectionActive = ref.watch(
      mobileShellSelectionActiveProvider(branch),
    );
    final offline = ref.watch(appOnlineStatusProvider).asData?.value == false;
    final content = Theme(
      data: MobileAppTheme.resolve(Theme.of(context)),
      child: MobileShellScope(
        hosted: true,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body:
              useRail
                  ? _buildRailLayout(
                    context,
                    selectionActive: selectionActive,
                    offline: offline,
                  )
                  : _buildBottomNavigationLayout(
                    context,
                    selectionActive: selectionActive,
                    offline: offline,
                  ),
        ),
      ),
    );
    return AppBackdropSceneScope(
      owner: 'app.mobile.shell',
      policy: MobileNavigationConfig.backdropPolicyForBranch(branch),
      child: content,
    );
  }

  Widget _buildBottomNavigationLayout(
    BuildContext context, {
    required bool selectionActive,
    required bool offline,
  }) {
    return Column(
      children: [
        _MobileTopBar(branch: widget.navigationShell.currentIndex),
        if (offline) const _MobileSystemBanner(),
        Expanded(child: _moduleContent()),
        if (!selectionActive) ...[
          MusicMobileMiniPlayerSlot(onOpenPlayer: _openNowPlaying),
          _MobileBottomNavigation(
            selectedIndex: _destinationIndex,
            onSelected: _selectDestination,
            portalStyle:
                widget.navigationShell.currentIndex ==
                MobileNavigationConfig.portalBranch,
            musicStyle:
                widget.navigationShell.currentIndex ==
                MobileNavigationConfig.musicBranch,
          ),
        ],
      ],
    );
  }

  Widget _buildRailLayout(
    BuildContext context, {
    required bool selectionActive,
    required bool offline,
  }) {
    return SafeArea(
      child: Row(
        children: [
          if (!selectionActive)
            _MobileNavigationRail(
              selectedIndex: _destinationIndex,
              onSelected: _selectDestination,
              portalStyle:
                  widget.navigationShell.currentIndex ==
                  MobileNavigationConfig.portalBranch,
              musicStyle:
                  widget.navigationShell.currentIndex ==
                  MobileNavigationConfig.musicBranch,
            ),
          Expanded(
            child: Column(
              children: [
                _MobileTopBar(branch: widget.navigationShell.currentIndex),
                if (offline) const _MobileSystemBanner(),
                Expanded(child: _moduleContent()),
                if (!selectionActive)
                  MusicMobileMiniPlayerSlot(onOpenPlayer: _openNowPlaying),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int get _destinationIndex {
    return MobileNavigationConfig.destinationIndexForBranch(
      widget.navigationShell.currentIndex,
    );
  }

  Widget _moduleContent() {
    return ModuleSwitchTransition(
      transitionKey: widget.navigationShell.currentIndex,
      forward: _transitionForward,
      child: widget.navigationShell,
    );
  }

  void _selectDestination(int index) {
    final branch = MobileNavigationConfig.branchForDestination(index);
    widget.navigationShell.goBranch(
      branch,
      initialLocation: branch == widget.navigationShell.currentIndex,
    );
  }

  void _openNowPlaying() {
    context.push('/music/now-playing');
  }
}

/// 判断当前平台和视口是否应启用统一移动端壳层。
bool shouldUseResponsiveMobileShell({
  required bool mobilePlatform,
  required double width,
}) {
  return mobilePlatform || ResponsiveBreakpoints.isCompact(width);
}

class _MobileTopBar extends ConsumerWidget {
  const _MobileTopBar({required this.branch});

  final int branch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final portalStyle = branch == MobileNavigationConfig.portalBranch;
    final musicStyle = branch == MobileNavigationConfig.musicBranch;
    final backdropActive = _localBackdropActive(ref);
    if (portalStyle) {
      return Theme(
        data: PortalMobileTheme.resolve(
          context,
          backdropActive: backdropActive,
        ),
        child: Builder(
          builder:
              (context) => _buildTopBar(
                context,
                l10n: l10n,
                backdropActive: backdropActive,
              ),
        ),
      );
    }
    if (musicStyle) {
      return Theme(
        data: MusicBackdropTheme.resolve(
          Theme.of(context),
          backdropActive: backdropActive,
        ),
        child: Builder(
          builder:
              (context) => _buildTopBar(
                context,
                l10n: l10n,
                backdropActive: backdropActive,
              ),
        ),
      );
    }
    return _buildTopBar(context, l10n: l10n, backdropActive: false);
  }

  Widget _buildTopBar(
    BuildContext context, {
    required AppLocalizations l10n,
    required bool backdropActive,
  }) {
    final portalStyle = branch == MobileNavigationConfig.portalBranch;
    final musicStyle = branch == MobileNavigationConfig.musicBranch;
    final surface =
        portalStyle
            ? PortalMobileTheme.chromeSurface(
              context,
              backdropActive: backdropActive,
            )
            : musicStyle
            ? _musicChromeSurface(context, backdropActive: backdropActive)
            : _mobileChromeSurface(context, backdropActive: backdropActive);
    final outline =
        portalStyle
            ? PortalMobileTheme.chromeOutline(
              context,
              backdropActive: backdropActive,
            )
            : musicStyle
            ? _musicChromeOutline(context)
            : _mobileChromeOutline(context, backdropActive: backdropActive);
    final foreground =
        musicStyle
            ? context.musicColors.onSurface
            : context.mobileColors.textPrimary;
    return SafeArea(
      bottom: false,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surface,
          border: Border(bottom: BorderSide(color: outline)),
        ),
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _title(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (branch == MobileNavigationConfig.musicBranch)
                  const MusicMobileTopBarActions(),
                IconButton(
                  tooltip: l10n.searchTitle,
                  onPressed:
                      () => context.push(
                        '/search?scope=${MobileNavigationConfig.searchScopeForBranch(branch)}',
                      ),
                  icon: Icon(Icons.search_rounded, size: 22),
                  style: IconButton.styleFrom(
                    foregroundColor: foreground,
                    minimumSize: const Size.square(
                      MobileLayoutTokens.minimumTarget,
                    ),
                  ),
                ),
                _MobileActivityButton(foregroundColor: foreground),
                const SizedBox(width: 4),
                const UserAvatarMenu(size: 32, directToProfile: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _title(AppLocalizations l10n) {
    return switch (branch) {
      0 => l10n.mobileNavHome,
      1 => l10n.mobileNavFiles,
      2 => l10n.mobileNavMusic,
      3 => l10n.portalDockPhotos,
      4 => l10n.portalDockMovies,
      _ => l10n.mobileNavReader,
    };
  }
}

class _MobileActivityButton extends ConsumerWidget {
  const _MobileActivityButton({required this.foregroundColor});

  final Color foregroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(mobileShellActivityProvider);
    final failed = activity.failedTaskCount > 0;
    final active = activity.activeTaskCount > 0;
    final indicatorColor =
        failed
            ? context.mobileColors.danger
            : active
            ? context.mobileColors.musicAccent
            : context.mobileColors.warmAccent;
    final visible = activity.isVisible;
    return IconButton(
      tooltip: AppLocalizations.of(context).mobileActivityCenter,
      onPressed: () => context.push('/activity'),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            Icons.notifications_none_rounded,
            size: 22,
            color: foregroundColor,
          ),
          if (visible)
            Positioned(
              top: -2,
              right: -3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: indicatorColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: context.mobileColors.surface,
                    width: 2,
                  ),
                ),
                child: const SizedBox.square(dimension: 9),
              ),
            ),
        ],
      ),
    );
  }
}

class _MobileSystemBanner extends StatelessWidget {
  const _MobileSystemBanner();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.mobileColors.surfaceSelected,
      child: SizedBox(
        height: 42,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 18,
                color: context.mobileColors.warmAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.of(context).mobileOfflineBanner,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.mobileColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileBottomNavigation extends ConsumerWidget {
  const _MobileBottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.portalStyle,
    required this.musicStyle,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool portalStyle;
  final bool musicStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backdropActive = _localBackdropActive(ref);
    if (portalStyle) {
      return Theme(
        data: PortalMobileTheme.resolve(
          context,
          backdropActive: backdropActive,
        ),
        child: Builder(
          builder:
              (context) =>
                  _buildNavigation(context, backdropActive: backdropActive),
        ),
      );
    }
    if (musicStyle) {
      return Theme(
        data: MusicBackdropTheme.resolve(
          Theme.of(context),
          backdropActive: backdropActive,
        ),
        child: Builder(
          builder:
              (context) =>
                  _buildNavigation(context, backdropActive: backdropActive),
        ),
      );
    }
    return _buildNavigation(context, backdropActive: false);
  }

  Widget _buildNavigation(
    BuildContext context, {
    required bool backdropActive,
  }) {
    final destinations = _destinations(AppLocalizations.of(context));
    final surface =
        portalStyle
            ? PortalMobileTheme.chromeSurface(
              context,
              backdropActive: backdropActive,
            )
            : musicStyle
            ? _musicChromeSurface(context, backdropActive: backdropActive)
            : _mobileChromeSurface(context, backdropActive: backdropActive);
    final outline =
        portalStyle
            ? PortalMobileTheme.chromeOutline(
              context,
              backdropActive: backdropActive,
            )
            : musicStyle
            ? _musicChromeOutline(context)
            : _mobileChromeOutline(context, backdropActive: backdropActive);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: outline)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var index = 0; index < destinations.length; index++)
                Expanded(
                  child: _MobileBottomDestination(
                    destination: destinations[index],
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileNavigationRail extends ConsumerWidget {
  const _MobileNavigationRail({
    required this.selectedIndex,
    required this.onSelected,
    required this.portalStyle,
    required this.musicStyle,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final bool portalStyle;
  final bool musicStyle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backdropActive = _localBackdropActive(ref);
    if (portalStyle) {
      return Theme(
        data: PortalMobileTheme.resolve(
          context,
          backdropActive: backdropActive,
        ),
        child: Builder(
          builder:
              (context) => _buildRail(context, backdropActive: backdropActive),
        ),
      );
    }
    if (musicStyle) {
      return Theme(
        data: MusicBackdropTheme.resolve(
          Theme.of(context),
          backdropActive: backdropActive,
        ),
        child: Builder(
          builder:
              (context) => _buildRail(context, backdropActive: backdropActive),
        ),
      );
    }
    return _buildRail(context, backdropActive: false);
  }

  Widget _buildRail(BuildContext context, {required bool backdropActive}) {
    final destinations = _destinations(AppLocalizations.of(context));
    return NavigationRail(
      minWidth: 80,
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      backgroundColor:
          portalStyle
              ? PortalMobileTheme.chromeSurface(
                context,
                backdropActive: backdropActive,
              )
              : musicStyle
              ? _musicChromeSurface(context, backdropActive: backdropActive)
              : _mobileChromeSurface(context, backdropActive: backdropActive),
      labelType: NavigationRailLabelType.all,
      destinations: [
        for (final destination in destinations)
          NavigationRailDestination(
            icon: Icon(destination.icon),
            selectedIcon: Icon(destination.selectedIcon),
            label: Text(destination.label),
          ),
      ],
    );
  }
}

bool _localBackdropActive(WidgetRef ref) {
  return ref.watch(mobileShellLocalBackdropActiveProvider);
}

Color _musicChromeSurface(
  BuildContext context, {
  required bool backdropActive,
}) {
  final colors = context.musicColors;
  final light = Theme.of(context).brightness == Brightness.light;
  final requestedAlpha = backdropActive ? 0.36 : (light ? 0.42 : 0.82);
  final alpha =
      requestedAlpha < colors.surfaceContainer.a
          ? requestedAlpha
          : colors.surfaceContainer.a;
  return colors.surfaceContainer.withValues(alpha: alpha);
}

Color _musicChromeOutline(BuildContext context) {
  final colors = context.musicColors;
  final requestedAlpha =
      Theme.of(context).brightness == Brightness.light ? 0.52 : 0.72;
  final alpha =
      requestedAlpha < colors.outline.a ? requestedAlpha : colors.outline.a;
  return colors.outline.withValues(alpha: alpha);
}

Color _mobileChromeSurface(
  BuildContext context, {
  required bool backdropActive,
}) {
  return context.mobileColors.pageMask.withValues(
    alpha: backdropActive ? 0.58 : 0.92,
  );
}

Color _mobileChromeOutline(
  BuildContext context, {
  required bool backdropActive,
}) {
  return context.mobileColors.outline.withValues(
    alpha: backdropActive ? 0.72 : 1,
  );
}

class _MobileBottomDestination extends StatelessWidget {
  const _MobileBottomDestination({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _MobileDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: destination.label,
      child: MobilePressable(
        semanticLabel: destination.label,
        onTap: onTap,
        child: SizedBox.expand(
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: AnimatedContainer(
                  duration: MobileLayoutTokens.stateDuration,
                  curve: MobileLayoutTokens.motionCurve,
                  width: selected ? 28 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: context.mobileColors.musicAccent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? destination.selectedIcon : destination.icon,
                    size: 22,
                    color:
                        selected
                            ? context.mobileColors.musicAccent
                            : context.mobileColors.textSecondary,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    destination.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          selected
                              ? context.mobileColors.textPrimary
                              : context.mobileColors.textSecondary,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<_MobileDestination> _destinations(AppLocalizations l10n) {
  return [
    _MobileDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: l10n.mobileNavHome,
    ),
    _MobileDestination(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder_rounded,
      label: l10n.mobileNavFiles,
    ),
    _MobileDestination(
      icon: Icons.music_note_outlined,
      selectedIcon: Icons.music_note_rounded,
      label: l10n.mobileNavMusic,
    ),
    _MobileDestination(
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library_rounded,
      label: l10n.portalDockPhotos,
    ),
    _MobileDestination(
      icon: Icons.movie_outlined,
      selectedIcon: Icons.movie_rounded,
      label: l10n.portalDockMovies,
    ),
    _MobileDestination(
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      label: l10n.mobileNavReader,
    ),
  ];
}

class _MobileDestination {
  const _MobileDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
