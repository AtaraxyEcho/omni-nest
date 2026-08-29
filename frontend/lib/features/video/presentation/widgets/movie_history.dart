import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_common_widgets.dart';

class HistorySection extends StatelessWidget {
  const HistorySection({
    required this.items,
    this.onDelete,
    this.onClearAll,
    super.key,
  });

  final List<MovieWatchHistory> items;
  final ValueChanged<MovieWatchHistory>? onDelete;
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: MovieSectionHeading(
                title: 'Watch History',
                subtitle: AppLocalizations.of(context).videoHistorySubtitle,
              ),
            ),
            if (onClearAll != null && items.isNotEmpty)
              TextButton.icon(
                onPressed: onClearAll,
                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                label: Text(AppLocalizations.of(context).videoClearHistory),
              ),
          ],
        ),
        const SizedBox(height: 22),
        if (items.isEmpty)
          EmptyMovieState(
            message: AppLocalizations.of(context).videoNoWatchHistory,
          )
        else
          for (final item in items) HistoryRow(item: item, onDelete: onDelete),
      ],
    );
  }
}

class HistoryRow extends StatelessWidget {
  const HistoryRow({required this.item, this.onDelete, super.key});

  final MovieWatchHistory item;
  final ValueChanged<MovieWatchHistory>? onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.go('/video/${item.videoItemId}/play'),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.videoColors.surfaceContainerHigh.withValues(
            alpha: 0.72,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.videoColors.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.history_rounded, color: context.videoColors.primary),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: context.videoColors.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${item.progressPercent.toStringAsFixed(1)}%',
              style: TextStyle(color: context.videoColors.onSurfaceVariant),
            ),
            if (onDelete != null) ...[
              SizedBox(width: 8),
              IconButton(
                tooltip: AppLocalizations.of(context).coreDelete,
                icon: Icon(Icons.close_rounded, size: 18),
                color: context.videoColors.onSurfaceVariant,
                onPressed: () => onDelete!.call(item),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
