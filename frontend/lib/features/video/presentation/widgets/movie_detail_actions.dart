import 'package:file_picker/file_picker.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:omninest/core/widgets/file_purge_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_feedback.dart';
import 'package:omninest/features/video/presentation/widgets/movie_styles.dart';

part 'movie_detail_action_tiles.dart';

class MovieDetailActionBar extends ConsumerWidget {
  const MovieDetailActionBar({
    required this.item,
    required this.canManage,
    super.key,
  });

  final MovieVideoItem item;
  final bool canManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favoriteState = ref.watch(movieFavoriteProvider(item.id));
    final isFavorite = favoriteState.asData?.value.favorite ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Tooltip(
            message:
                item.available
                    ? AppLocalizations.of(context).videoPlay
                    : AppLocalizations.of(context).videoFileUnavailable,
            child: FilledButton.icon(
              onPressed:
                  item.id.isEmpty || !item.available
                      ? null
                      : () => _playItem(context, ref, item),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(AppLocalizations.of(context).videoPlay),
              style: movieFilledButtonStyle(context),
            ),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await ref
                    .read(movieCenterControllerProvider.notifier)
                    .toggleFavorite(item, favorite: !isFavorite);
                if (!context.mounted) return;
                ref.invalidate(movieFavoriteProvider(item.id));
              } catch (error) {
                if (context.mounted) {
                  showMovieFeedback(
                    context,
                    movieErrorMessage(error),
                    isError: true,
                  );
                }
              }
            },
            icon: Icon(
              isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
            ),
            label: Text(
              isFavorite
                  ? AppLocalizations.of(context).videoFavorited
                  : AppLocalizations.of(context).videoFavorite,
            ),
            style: movieOutlinedButtonStyle(context),
          ),
          if (canManage) ...[
            OutlinedButton.icon(
              onPressed: () => _showSubtitleSheet(context, ref, item),
              icon: const Icon(Icons.subtitles_rounded),
              label: Text(AppLocalizations.of(context).videoSubtitle),
              style: movieOutlinedButtonStyle(context),
            ),
            OutlinedButton.icon(
              onPressed: () => _showAudioSheet(context, ref, item),
              icon: const Icon(Icons.audiotrack_rounded),
              label: Text(AppLocalizations.of(context).videoAudio),
              style: movieOutlinedButtonStyle(context),
            ),
          ],
          OutlinedButton.icon(
            onPressed: () => _deleteItem(context, ref),
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(AppLocalizations.of(context).videoDelete),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 18),
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.error.withValues(alpha: 0.40),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteItem(BuildContext context, WidgetRef ref) async {
    try {
      final deleted = await confirmAndRunFilePurge(
        context,
        resourceName: item.title,
        action: (cascade) async {
          await ref
              .read(movieCenterControllerProvider.notifier)
              .deleteItem(item, cascade: cascade);
        },
      );
      if (!deleted || !context.mounted) return;
      if (context.mounted) {
        showMovieFeedback(
          context,
          AppLocalizations.of(context).videoMovedToRecycleBin,
        );
        context.go('/video');
      }
    } catch (error) {
      if (context.mounted) {
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    }
  }

  Future<void> _playItem(
    BuildContext context,
    WidgetRef ref,
    MovieVideoItem item,
  ) async {
    // 播放页通过 playbackPlan 接口恢复上次播放位置。
    if (context.mounted) {
      final router = GoRouter.of(context);
      router.go('/video/${item.id}/play');
    }
  }

  void _showSubtitleSheet(
    BuildContext context,
    WidgetRef ref,
    MovieVideoItem item,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.videoColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) =>
              _SubtitleSheetContent(videoItemId: item.id, title: item.title),
    );
  }

  void _showAudioSheet(
    BuildContext context,
    WidgetRef ref,
    MovieVideoItem item,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.videoColors.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _AudioSheetContent(item: item),
    );
  }
}

class _SubtitleSheetContent extends ConsumerStatefulWidget {
  const _SubtitleSheetContent({required this.videoItemId, required this.title});

  final String videoItemId;
  final String title;

  @override
  ConsumerState<_SubtitleSheetContent> createState() =>
      _SubtitleSheetContentState();
}

class _SubtitleSheetContentState extends ConsumerState<_SubtitleSheetContent> {
  bool _uploading = false;

  @override
  Widget build(BuildContext context) {
    final subtitlesAsync = ref.watch(
      movieSubtitlesProvider(widget.videoItemId),
    );
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).videoSubtitleManagement,
                  style: TextStyle(
                    color: context.videoColors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).coreClose,
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: context.videoColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.videoColors.onSurfaceVariant),
          ),
          SizedBox(height: 20),
          subtitlesAsync.when(
            data: (subtitles) {
              if (subtitles.isEmpty) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Text(
                    AppLocalizations.of(context).videoNoSubtitles,
                    style: TextStyle(
                      color: context.videoColors.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final track in subtitles)
                      _SubtitleTile(
                        track: track,
                        onDelete:
                            track.embedded
                                ? null
                                : () => _deleteSubtitle(track),
                      ),
                  ],
                ),
              );
            },
            loading:
                () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            error:
                (_, _) => Padding(
                  padding: EdgeInsets.only(bottom: 24),
                  child: Text(
                    AppLocalizations.of(context).videoSubtitleLoadFailed,
                    style: TextStyle(
                      color: context.videoColors.onSurfaceVariant,
                    ),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _uploading ? null : _pickAndUploadSubtitle,
              icon:
                  _uploading
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.upload_file_rounded),
              label: Text(
                _uploading
                    ? AppLocalizations.of(context).videoUploading
                    : AppLocalizations.of(context).videoUploadSubtitle,
              ),
              style: movieOutlinedButtonStyle(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadSubtitle() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt', 'ass', 'ssa', 'vtt'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) return;

    if (!mounted) return;
    final language = await _promptLanguage();
    if (language == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      await ref
          .read(movieCenterControllerProvider.notifier)
          .uploadSubtitle(
            videoItemId: widget.videoItemId,
            fileName: file.name,
            bytes: file.bytes!,
            mimeType: _subtitleMime(file.extension),
            language: language,
          );
      if (!mounted) return;
      ref.invalidate(movieSubtitlesProvider(widget.videoItemId));
      if (mounted) {
        showMovieFeedback(
          context,
          AppLocalizations.of(context).videoSubtitleUploaded,
        );
      }
    } catch (error) {
      if (mounted) {
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteSubtitle(SubtitleTrack track) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: context.videoColors.surfaceContainerHigh,
            title: Text(
              AppLocalizations.of(context).videoDeleteSubtitleTitle,
              style: TextStyle(color: context.videoColors.onSurface),
            ),
            content: Text(
              AppLocalizations.of(
                context,
              ).videoDeleteSubtitleMessage(track.label),
              style: TextStyle(color: context.videoColors.onSurfaceVariant),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(AppLocalizations.of(context).videoCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(AppLocalizations.of(context).videoDelete),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(movieCenterControllerProvider.notifier)
          .deleteSubtitle(track.id);
      if (!mounted) return;
      ref.invalidate(movieSubtitlesProvider(widget.videoItemId));
      if (mounted) {
        showMovieFeedback(
          context,
          AppLocalizations.of(context).videoSubtitleDeleted,
        );
      }
    } catch (error) {
      if (mounted) {
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    }
  }

  Future<String?> _promptLanguage() async {
    final controller = TextEditingController(text: 'chi');
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: context.videoColors.surfaceContainerHigh,
            title: Text(
              AppLocalizations.of(context).videoSubtitleLanguage,
              style: TextStyle(color: context.videoColors.onSurface),
            ),
            content: TextField(
              controller: controller,
              style: TextStyle(color: context.videoColors.onSurface),
              decoration: InputDecoration(
                hintText:
                    AppLocalizations.of(context).videoSubtitleLanguageHint,
                hintStyle: TextStyle(
                  color: context.videoColors.onSurfaceVariant,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context).videoCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: Text(AppLocalizations.of(context).videoConfirm),
              ),
            ],
          ),
    );
  }

  String _subtitleMime(String? ext) {
    return switch (ext) {
      'srt' => 'application/x-subrip',
      'ass' || 'ssa' => 'text/x-ssa',
      'vtt' => 'text/vtt',
      _ => 'application/octet-stream',
    };
  }
}

// Web 端不支持的音频编码
const _webUnsupportedAudio = ['ac3', 'eac3', 'dts', 'dts-hd', 'truehd', 'pcm'];

class _AudioSheetContent extends ConsumerStatefulWidget {
  const _AudioSheetContent({required this.item});

  final MovieVideoItem item;

  @override
  ConsumerState<_AudioSheetContent> createState() => _AudioSheetContentState();
}

class _AudioSheetContentState extends ConsumerState<_AudioSheetContent> {
  bool _extracting = false;

  bool get _needsTranscode {
    final codec = widget.item.audioCodec?.toLowerCase().trim();
    return codec != null && _webUnsupportedAudio.contains(codec);
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(moviePlaybackPlanProvider(widget.item.id));
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppLocalizations.of(context).videoAudioManagement,
                  style: TextStyle(
                    color: context.videoColors.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: AppLocalizations.of(context).coreClose,
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.close_rounded,
                  color: context.videoColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            widget.item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.videoColors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          // 原始音频信息
          _AudioInfoTile(
            icon: Icons.high_quality_rounded,
            label: AppLocalizations.of(context).videoOriginalAudio,
            codec:
                widget.item.audioCodec ??
                AppLocalizations.of(context).videoUnknown,
            isCompatible: !_needsTranscode,
          ),
          const SizedBox(height: 8),
          // 缓存音频状态
          planAsync.when(
            data:
                (plan) => _AudioInfoTile(
                  icon: Icons.cached_rounded,
                  label: AppLocalizations.of(context).videoCompatibleAudioCache,
                  codec:
                      plan.hasAudioCache
                          ? 'AAC'
                          : AppLocalizations.of(context).videoNotExtracted,
                  isCompatible: true,
                  hasCache: plan.hasAudioCache,
                ),
            loading:
                () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            error:
                (_, _) => _AudioInfoTile(
                  icon: Icons.cached_rounded,
                  label: AppLocalizations.of(context).videoCompatibleAudioCache,
                  codec: AppLocalizations.of(context).videoLoadFailed,
                  isCompatible: true,
                ),
          ),
          const SizedBox(height: 16),
          // 说明文字
          if (_needsTranscode)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orange,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).videoAudioIncompatibleNotice(
                        widget.item.audioCodec ?? '',
                      ),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // 操作按钮
          SizedBox(
            width: double.infinity,
            child: planAsync.when(
              data: (plan) {
                if (plan.hasAudioCache) {
                  return OutlinedButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: Text(
                      AppLocalizations.of(context).videoCompatibleAudioReady,
                    ),
                    style: movieOutlinedButtonStyle(context),
                  );
                }
                return FilledButton.icon(
                  onPressed: _extracting ? null : _extractAudio,
                  icon:
                      _extracting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                          : const Icon(Icons.audio_file_rounded),
                  label: Text(
                    _extracting
                        ? AppLocalizations.of(context).videoExtracting
                        : AppLocalizations.of(
                          context,
                        ).videoExtractCompatibleAudio,
                  ),
                  style: movieFilledButtonStyle(context),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _extractAudio() async {
    setState(() => _extracting = true);
    try {
      await ref
          .read(movieCenterControllerProvider.notifier)
          .createAudioExtractTask(widget.item);
      if (!mounted) return;
      ref.invalidate(moviePlaybackPlanProvider(widget.item.id));
      if (mounted) {
        showMovieFeedback(
          context,
          AppLocalizations.of(context).videoAudioExtractCreated,
        );
      }
    } catch (error) {
      if (mounted) {
        showMovieFeedback(context, movieErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }
}
