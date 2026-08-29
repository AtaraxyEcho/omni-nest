part of 'movie_detail_actions.dart';

class _SubtitleTile extends StatelessWidget {
  const _SubtitleTile({required this.track, this.onDelete});

  final SubtitleTrack track;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            track.kind == 'FORCED'
                ? Icons.closed_caption_disabled_rounded
                : Icons.closed_caption_rounded,
            color: context.videoColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.label,
                  style: TextStyle(
                    color: context.videoColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${track.language} · ${track.embedded ? AppLocalizations.of(context).videoEmbedded : AppLocalizations.of(context).videoExternal}',
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant.withValues(
                      alpha: 0.62,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (track.embedded)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                AppLocalizations.of(context).videoEmbedded,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
              tooltip: AppLocalizations.of(context).videoDeleteSubtitleTooltip,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _AudioInfoTile extends StatelessWidget {
  const _AudioInfoTile({
    required this.icon,
    required this.label,
    required this.codec,
    required this.isCompatible,
    this.hasCache,
  });

  final IconData icon;
  final String label;
  final String codec;
  final bool isCompatible;
  final bool? hasCache;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.videoColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.videoColors.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  codec,
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant.withValues(
                      alpha: 0.62,
                    ),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (hasCache == true)
            _AudioStatusBadge(
              label: AppLocalizations.of(context).videoCached,
              color: Colors.green,
            )
          else if (!isCompatible)
            _AudioStatusBadge(
              label: AppLocalizations.of(context).videoIncompatible,
              color: Colors.orange,
            )
          else
            _AudioStatusBadge(
              label: AppLocalizations.of(context).videoCompatible,
              color: Colors.blue,
            ),
        ],
      ),
    );
  }
}

class _AudioStatusBadge extends StatelessWidget {
  const _AudioStatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
