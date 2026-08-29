import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_shell.dart';

class TechnicalMetadataSection extends ConsumerStatefulWidget {
  const TechnicalMetadataSection({required this.item, this.width, super.key});

  final MovieVideoItem item;
  final double? width;

  @override
  ConsumerState<TechnicalMetadataSection> createState() =>
      _TechnicalMetadataSectionState();
}

class _TechnicalMetadataSectionState
    extends ConsumerState<TechnicalMetadataSection> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final item = widget.item;
    final nfoAsync = ref.watch(movieNfoPreviewProvider(item.id));
    final w = widget.width ?? MediaQuery.sizeOf(context).width;
    final titleSize = ms(w, 17);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.videoTechnicalInfo,
                  style: TextStyle(
                    color: context.videoColors.onSurface,
                    fontSize: titleSize,
                    height: 24 / 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: context.videoColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetaChip(
                icon: Icons.info_outline_rounded,
                label: l10n.videoScrapeStatus,
                value: _statusLabel(item.metadataStatus, l10n),
                valueColor: _statusColor(item.metadataStatus),
              ),
              _MetaChip(
                icon: Icons.description_outlined,
                label: l10n.videoNfoExport,
                value: nfoAsync.when(
                  data:
                      (nfo) =>
                          nfo.status == 'EXPORTED'
                              ? l10n.videoExported
                              : l10n.videoNotExported,
                  error: (_, _) => l10n.videoUnknown,
                  loading: () => l10n.videoDetecting,
                ),
              ),
              if (item.containerFormat != null)
                _MetaChip(
                  icon: Icons.folder_rounded,
                  label: l10n.videoContainerFormat,
                  value: item.containerFormat!,
                ),
              _MetaChip(
                icon: Icons.timer_outlined,
                label: l10n.videoDuration,
                value: item.runtimeText,
              ),
              _MetaChip(
                icon: Icons.category_rounded,
                label: l10n.videoType,
                value:
                    item.mediaType == 'MOVIE'
                        ? l10n.videoSectionMovies
                        : l10n.videoSectionTvShows,
              ),
            ],
          ),
        ],
      ],
    );
  }

  String _statusLabel(String? status, AppLocalizations l10n) {
    return switch (status) {
      'MATCHED' => l10n.videoMatched,
      'PENDING' => l10n.videoPendingScrape,
      'FAILED' => l10n.videoMatchFailed,
      'MANUAL' => l10n.videoManualEdit,
      _ => status ?? l10n.videoUnknown,
    };
  }

  Color _statusColor(String? status) {
    return switch (status) {
      'MATCHED' => Colors.greenAccent,
      'PENDING' => Colors.amber,
      'FAILED' => Colors.redAccent,
      _ => context.videoColors.onSurfaceVariant,
    };
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.videoColors.surfaceContainerHighest.withValues(
          alpha: 0.40,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: context.videoColors.primary, size: 16),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.videoColors.onSurfaceVariant.withValues(
                    alpha: 0.62,
                  ),
                  fontSize: 11,
                  height: 14 / 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? context.videoColors.onSurface,
                  fontSize: 13,
                  height: 18 / 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
