import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/presentation/widgets/movie_shell.dart';

class MovieDetailUserData extends ConsumerWidget {
  const MovieDetailUserData({required this.videoItemId, this.width, super.key});

  final String videoItemId;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(movieItemHistoryProvider(videoItemId));
    return historyAsync.when(
      data: (history) {
        final progress =
            history != null && history.durationSeconds > 0
                ? history.positionSeconds / history.durationSeconds
                : 0.0;
        final w = width ?? MediaQuery.sizeOf(context).width;
        final titleSize = ms(w, 17);
        final bodySize = ms(w, 13);
        final hintSize = ms(w, 12);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).videoWatchRecord,
              style: TextStyle(
                color: context.videoColors.onSurface,
                fontSize: titleSize,
                height: 24 / 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 14),
            if (history != null) ...[
              Row(
                children: [
                  Icon(
                    history.completed
                        ? Icons.check_circle_rounded
                        : Icons.play_circle_rounded,
                    color:
                        history.completed
                            ? Colors.greenAccent
                            : context.videoColors.primary,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    history.completed
                        ? AppLocalizations.of(context).videoWatched
                        : AppLocalizations.of(context).videoWatching,
                    style: TextStyle(
                      color: context.videoColors.onSurfaceVariant.withValues(
                        alpha: 0.82,
                      ),
                      fontSize: bodySize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!history.completed && history.durationSeconds > 0) ...[
                    SizedBox(width: 12),
                    Text(
                      '${_formatDuration(history.positionSeconds)} / ${_formatDuration(history.durationSeconds)}',
                      style: TextStyle(
                        color: context.videoColors.onSurfaceVariant.withValues(
                          alpha: 0.62,
                        ),
                        fontSize: hintSize,
                      ),
                    ),
                  ],
                ],
              ),
              if (!history.completed && history.durationSeconds > 0) ...[
                SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 3,
                    backgroundColor:
                        context.videoColors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      context.videoColors.primary,
                    ),
                  ),
                ),
              ],
              if (history.playedAt != null) ...[
                SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).videoLastPlayedTime(
                    _formatTime(context, history.playedAt!),
                  ),
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant.withValues(
                      alpha: 0.52,
                    ),
                    fontSize: hintSize,
                  ),
                ),
              ],
            ] else ...[
              Text(
                AppLocalizations.of(context).videoNoWatchRecord,
                style: TextStyle(
                  color: context.videoColors.onSurfaceVariant.withValues(
                    alpha: 0.52,
                  ),
                  fontSize: bodySize,
                ),
              ),
            ],
          ],
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h${m.toString().padLeft(2, '0')}m';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _formatTime(BuildContext context, DateTime time) {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return l10n.videoJustNow;
    if (diff.inHours < 1) return l10n.videoMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.videoHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.videoDaysAgo(diff.inDays);
    return '${time.month}/${time.day}';
  }
}
