part of 'movie_shell.dart';

class _MovieMobileShell extends StatelessWidget {
  const _MovieMobileShell({
    required this.section,
    required this.child,
    required this.canManage,
    required this.childOwnsScroll,
    this.onSectionSelected,
    this.onRefresh,
    this.onBack,
  });

  final MovieSection section;
  final Widget child;
  final bool canManage;
  final bool childOwnsScroll;
  final ValueChanged<MovieSection>? onSectionSelected;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hosted = MobileShellScope.isHosted(context);
    final navIndex = _selectedIndex;
    final isSettingsSection = navIndex == 4;

    final pageContent =
        isSettingsSection
            ? Column(
              children: [
                if (!hosted)
                  _MovieMobileTopBar(
                    section: section,
                    onSectionSelected: onSectionSelected,
                  ),
                Expanded(
                  child: _MovieMorePage(onSectionSelected: onSectionSelected),
                ),
              ],
            )
            : childOwnsScroll
            ? Column(
              children: [
                if (!hosted)
                  _MovieMobileTopBar(
                    section: section,
                    onSectionSelected: onSectionSelected,
                  ),
                Expanded(
                  child: RefreshIndicator(
                    color: context.videoColors.primaryContainer,
                    onRefresh: onRefresh ?? () async {},
                    child: MovieSectionTransition(
                      section: section,
                      slideDistance: 0.024,
                      child: child,
                    ),
                  ),
                ),
              ],
            )
            : RefreshIndicator(
              displacement: 40,
              edgeOffset: hosted ? 0 : 64,
              strokeWidth: 2.5,
              color: context.videoColors.primaryContainer,
              onRefresh: () async {
                await (onRefresh ?? () async {})();
                await Future<void>.delayed(const Duration(milliseconds: 200));
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  if (!hosted)
                    SliverAppBar(
                      pinned: true,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      backgroundColor: Colors.transparent,
                      surfaceTintColor: Colors.transparent,
                      leading: IconButton(
                        onPressed: () => context.go('/portal'),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: context.videoColors.onSurfaceVariant,
                        ),
                        tooltip: AppLocalizations.of(context).videoBackToPortal,
                      ),
                      title: Text(
                        l10n.portalDockMovies,
                        style: TextStyle(
                          color: context.videoColors.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      actions: [
                        Consumer(
                          builder:
                              (context, ref, _) => MediaImportButton(
                                subsystemDirectory: 'Media',
                                onImportComplete: onRefresh ?? () async {},
                                style: ImportButtonStyle.iconButton,
                                color: context.videoColors.onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: () => _showSearchDialog(context),
                          icon: Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: context.videoColors.onSurfaceVariant,
                          ),
                          tooltip: l10n.videoSearch,
                        ),
                        const NotificationIcon(size: 20),
                        const SizedBox(width: 8),
                        const UserAvatarMenu(),
                        const SizedBox(width: 8),
                      ],
                      flexibleSpace: Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surface.withValues(alpha: 0.78),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                    sliver: SliverToBoxAdapter(
                      child: MovieSectionTransition(
                        section: section,
                        slideDistance: 0.024,
                        child: child,
                      ),
                    ),
                  ),
                ],
              ),
            );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onBack?.call();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: Builder(
          builder: (context) {
            final content = Column(
              children: [
                if (hosted)
                  _MovieMobileSectionBar(
                    section: section,
                    onSectionSelected: onSectionSelected,
                  ),
                Expanded(child: pageContent),
              ],
            );
            if (!hosted) {
              return content;
            }
            return MobilePageSurface(
              exposeBackdrop: true,
              backdropOpacity: 0.54,
              child: content,
            );
          },
        ),
        bottomNavigationBar:
            hosted
                ? null
                : WorkbenchNavigationBar(
                  currentIndex: navIndex,
                  onTap: (index) => _onNavTap(index),
                  items: [
                    WorkbenchNavigationItem(
                      icon: Icons.movie_outlined,
                      selectedIcon: Icons.movie_rounded,
                      label: l10n.videoSectionMovies,
                    ),
                    WorkbenchNavigationItem(
                      icon: Icons.tv_outlined,
                      selectedIcon: Icons.tv_rounded,
                      label: l10n.videoSectionTvShows,
                    ),
                    WorkbenchNavigationItem(
                      icon: Icons.animation_outlined,
                      selectedIcon: Icons.animation_rounded,
                      label: l10n.videoSectionAnime,
                    ),
                    WorkbenchNavigationItem(
                      icon: Icons.favorite_outline,
                      selectedIcon: Icons.favorite_rounded,
                      label: l10n.videoSectionFavorites,
                    ),
                  ],
                ),
      ),
    );
  }

  int get _selectedIndex => switch (section) {
    MovieSection.movies => 0,
    MovieSection.tvShows => 1,
    MovieSection.anime => 2,
    MovieSection.favorites => 3,
    _ => -1,
  };

  void _onNavTap(int index) {
    const sections = [
      MovieSection.movies,
      MovieSection.tvShows,
      MovieSection.anime,
      MovieSection.favorites,
    ];
    if (index >= 0 && index < sections.length) {
      onSectionSelected?.call(sections[index]);
    }
  }

  void _showSearchDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.videoSearch,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder:
          (context, animation, secondaryAnimation) => Dialog(
            backgroundColor: Colors.transparent,
            child: _MovieSearchOverlay(
              controller: controller,
              onSearch: (query) {
                if (query.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _MovieMobileSectionBar extends StatelessWidget {
  const _MovieMobileSectionBar({
    required this.section,
    required this.onSectionSelected,
  });

  final MovieSection section;
  final ValueChanged<MovieSection>? onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const sections = <MovieSection>[
      MovieSection.movies,
      MovieSection.tvShows,
      MovieSection.anime,
      MovieSection.favorites,
    ];
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final value = sections[index];
          return ChoiceChip(
            selected: value == section,
            showCheckmark: false,
            onSelected: (_) => onSectionSelected?.call(value),
            label: Text(value.labelOf(l10n)),
          );
        },
      ),
    );
  }
}

/// 移动端"更多"页面：合集、最近添加、继续观看、观看历史。
class _MovieMorePage extends StatelessWidget {
  const _MovieMorePage({this.onSectionSelected});

  final ValueChanged<MovieSection>? onSectionSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            l10n.videoBrowse,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: context.videoColors.onSurfaceVariant,
            ),
          ),
        ),
        _SettingsTile(
          icon: Icons.video_collection_rounded,
          label: l10n.videoSectionCollections,
          onTap: () => onSectionSelected?.call(MovieSection.collections),
        ),
        _SettingsTile(
          icon: Icons.new_releases_outlined,
          label: l10n.videoSectionRecent,
          onTap: () => onSectionSelected?.call(MovieSection.recent),
        ),
        _SettingsTile(
          icon: Icons.play_circle_outline_rounded,
          label: l10n.videoSectionContinueWatching,
          onTap: () => onSectionSelected?.call(MovieSection.continueWatching),
        ),
        _SettingsTile(
          icon: Icons.manage_history_rounded,
          label: l10n.videoSectionHistory,
          onTap: () => onSectionSelected?.call(MovieSection.history),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22, color: context.videoColors.onSurface),
      title: Text(
        label,
        style: TextStyle(color: context.videoColors.onSurface),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: context.videoColors.onSurfaceVariant,
      ),
      onTap: onTap,
    );
  }
}

/// 移动端简洁 TopBar：Portal 返回 + 标题 + 搜索 + 通知 + 头像。
class _MovieMobileTopBar extends StatelessWidget {
  const _MovieMobileTopBar({required this.section, this.onSectionSelected});

  final MovieSection section;
  final ValueChanged<MovieSection>? onSectionSelected;

  @override
  Widget build(BuildContext context) {
    return WorkbenchTopBar(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            // Portal 首页入口
            IconButton(
              onPressed: () => context.go('/portal'),
              icon: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: context.videoColors.onSurfaceVariant,
              ),
              tooltip: AppLocalizations.of(context).videoBackToPortal,
            ),
            const SizedBox(width: 4),
            // 标题
            Text(
              AppLocalizations.of(context).portalDockMovies,
              style: TextStyle(
                color: context.videoColors.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            // 搜索按钮
            IconButton(
              onPressed: () => _showSearchDialog(context),
              icon: Icon(
                Icons.search_rounded,
                size: 20,
                color: context.videoColors.onSurfaceVariant,
              ),
              tooltip: AppLocalizations.of(context).videoSearch,
            ),
            // 通知
            const NotificationIcon(size: 20),
            const SizedBox(width: 8),
            // 头像
            const UserAvatarMenu(),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: l10n.videoSearch,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder:
          (context, animation, secondaryAnimation) => Dialog(
            backgroundColor: Colors.transparent,
            child: _MovieSearchOverlay(
              controller: controller,
              onSearch: (query) {
                if (query.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _MovieBrand extends StatelessWidget {
  const _MovieBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OmniNest',
          style: TextStyle(
            color: context.videoColors.onSurface,
            fontSize: 24,
            height: 32 / 24,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppLocalizations.of(context).videoBrandVersion,
          style: TextStyle(
            color: context.videoColors.onSurfaceVariant,
            fontSize: 12,
            height: 16 / 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _MovieGroupLabel extends StatelessWidget {
  const _MovieGroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: context.videoColors.onSurfaceVariant.withValues(alpha: 0.74),
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _MovieNavItem extends StatefulWidget {
  const _MovieNavItem({
    required this.item,
    required this.label,
    required this.icon,
    required this.selected,
    required this.closeOnSelect,
    this.onSectionSelected,
  });

  final MovieSection? item;
  final String label;
  final IconData icon;
  final bool selected;
  final bool closeOnSelect;
  final ValueChanged<MovieSection>? onSectionSelected;

  @override
  State<_MovieNavItem> createState() => _MovieNavItemState();
}

class _MovieNavItemState extends State<_MovieNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              final target = widget.item;
              if (target != null) {
                widget.onSectionSelected?.call(target);
              }
              if (widget.closeOnSelect) {
                Navigator.of(context).maybePop();
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              height: 44,
              decoration: BoxDecoration(
                color:
                    widget.selected
                        ? context.videoColors.primaryContainer.withValues(
                          alpha: 0.92,
                        )
                        : _hovered
                        ? context.videoColors.surfaceContainerHighest
                            .withValues(alpha: 0.58)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      widget.selected
                          ? context.videoColors.primary.withValues(alpha: 0.34)
                          : _hovered
                          ? context.videoColors.outlineVariant.withValues(
                            alpha: 0.36,
                          )
                          : Colors.transparent,
                ),
                boxShadow:
                    widget.selected || _hovered
                        ? [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: widget.selected ? 0.12 : 0.06,
                            ),
                            blurRadius: widget.selected ? 12 : 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                        : const [],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 14),
                  AnimatedScale(
                    duration: const Duration(milliseconds: 160),
                    curve: Curves.easeOutCubic,
                    scale: widget.selected ? 1.06 : (_hovered ? 1.03 : 1.0),
                    child: Icon(
                      widget.icon,
                      size: 20,
                      color:
                          widget.selected
                              ? context.videoColors.onPrimaryContainer
                              : _hovered
                              ? context.videoColors.onSurface
                              : context.videoColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color:
                            widget.selected
                                ? context.videoColors.onPrimaryContainer
                                : _hovered
                                ? context.videoColors.onSurface
                                : context.videoColors.onSurfaceVariant,
                        fontSize: 12,
                        height: 16 / 12,
                        fontWeight:
                            widget.selected ? FontWeight.w800 : FontWeight.w700,
                        letterSpacing: 0,
                      ),
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MovieAccessHint extends StatelessWidget {
  const _MovieAccessHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerHigh.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        AppLocalizations.of(context).videoManageAdminOnly,
        style: TextStyle(
          color: context.videoColors.onSurfaceVariant,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
