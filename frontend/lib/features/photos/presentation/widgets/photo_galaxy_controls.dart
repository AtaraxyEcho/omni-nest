part of 'photo_galaxy_view.dart';

class _GalaxyControlBar extends StatelessWidget {
  const _GalaxyControlBar({
    required this.mode,
    required this.onModeChanged,
    required this.isLoading,
  });

  final PhotoGalaxyMode mode;
  final ValueChanged<PhotoGalaxyMode> onModeChanged;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.galaxyCanvasRaised.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.galaxyLine),
          ),
          child: PopupMenuButton<PhotoGalaxyMode>(
            tooltip: l10n.photosGalaxyFilter,
            icon: Icon(Icons.tune_rounded, color: colors.galaxyOnCanvas),
            onSelected: onModeChanged,
            itemBuilder:
                (context) => [
                  for (final item in PhotoGalaxyMode.values)
                    PopupMenuItem<PhotoGalaxyMode>(
                      value: item,
                      child: Row(
                        children: [
                          if (item == mode)
                            Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: colors.primaryContainer,
                            )
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          Text(_modeLabel(l10n, item)),
                        ],
                      ),
                    ),
                ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _modeLabel(l10n, mode),
          style: TextStyle(
            color: colors.galaxyOnCanvas,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (isLoading) ...[
          const SizedBox(width: 10),
          SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primaryContainer,
            ),
          ),
        ],
      ],
    );
  }
}

String _modeLabel(AppLocalizations l10n, PhotoGalaxyMode mode) {
  return switch (mode) {
    PhotoGalaxyMode.all => l10n.photosGalaxyModeAll,
    PhotoGalaxyMode.time => l10n.photosGalaxyModeTime,
    PhotoGalaxyMode.location => l10n.photosGalaxyModeLocation,
    PhotoGalaxyMode.people => l10n.photosGalaxyModePeople,
  };
}

class _GalaxySearchStatus extends StatelessWidget {
  const _GalaxySearchStatus({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.photosColors;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.galaxyCanvasRaised.withValues(alpha: 0.72),
          border: Border.all(color: colors.galaxyLine),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Icon(
                Icons.search_rounded,
                size: 17,
                color: colors.galaxyMuted,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.photosGalaxySearchActive(query),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: colors.galaxyMuted, fontSize: 12),
              ),
            ),
            IconButton(
              onPressed: onClear,
              tooltip: l10n.photosClear,
              icon: Icon(
                Icons.close_rounded,
                size: 17,
                color: colors.galaxyMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
