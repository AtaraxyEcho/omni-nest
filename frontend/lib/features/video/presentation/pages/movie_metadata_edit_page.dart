import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/core/widgets/app_error_view.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/core/widgets/workbench_panel.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_feedback.dart';
import 'package:omninest/features/video/presentation/widgets/movie_shell.dart';

class MovieMetadataEditPage extends ConsumerWidget {
  const MovieMetadataEditPage({required this.videoItemId, super.key});

  final String videoItemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(movieDetailProvider(videoItemId));
    return detail.when(
      data:
          (item) => MovieShell(
            section: MovieSection.management,
            onSectionSelected: (section) {
              ref
                  .read(movieCenterControllerProvider.notifier)
                  .selectSection(section);
              context.go('/video');
            },
            child: _MetadataEditForm(item: item),
          ),
      error:
          (error, stackTrace) => Scaffold(
            backgroundColor: context.videoColors.surface,
            body: AppErrorView(
              message: movieErrorMessage(error),
              onRetry: () => ref.invalidate(movieDetailProvider(videoItemId)),
            ),
          ),
      loading:
          () => Scaffold(
            backgroundColor: context.videoColors.surface,
            body: AppLoading.detail(),
          ),
    );
  }
}

class _MetadataEditForm extends ConsumerStatefulWidget {
  const _MetadataEditForm({required this.item});

  final MovieVideoItem item;

  @override
  ConsumerState<_MetadataEditForm> createState() => _MetadataEditFormState();
}

class _MetadataEditFormState extends ConsumerState<_MetadataEditForm> {
  late final TextEditingController _titleController;
  late final TextEditingController _originalTitleController;
  late final TextEditingController _releaseDateController;
  late final TextEditingController _runtimeController;
  late final TextEditingController _posterFileIdController;
  late final TextEditingController _backdropFileIdController;
  late final TextEditingController _overviewController;
  String _metadataStatus = 'MANUAL';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _titleController = TextEditingController(text: item.title);
    _originalTitleController = TextEditingController(
      text: item.originalTitle ?? '',
    );
    _releaseDateController = TextEditingController(
      text: item.releaseDate?.toIso8601String().split('T').first ?? '',
    );
    _runtimeController = TextEditingController(
      text:
          item.runtimeSeconds == null
              ? ''
              : (item.runtimeSeconds! ~/ 60).toString(),
    );
    _posterFileIdController = TextEditingController(
      text: item.posterFileId ?? '',
    );
    _backdropFileIdController = TextEditingController(
      text: item.backdropFileId ?? '',
    );
    _overviewController = TextEditingController(text: item.overview ?? '');
    _metadataStatus =
        {'PENDING', 'MATCHED', 'MANUAL', 'FAILED'}.contains(item.metadataStatus)
            ? item.metadataStatus
            : 'MANUAL';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _originalTitleController.dispose();
    _releaseDateController.dispose();
    _runtimeController.dispose();
    _posterFileIdController.dispose();
    _backdropFileIdController.dispose();
    _overviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EditHeader(item: widget.item),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1040;
            final coverPanel = _CoverEditPanel(
              item: widget.item,
              posterFileIdController: _posterFileIdController,
              backdropFileIdController: _backdropFileIdController,
            );
            final formPanel = _MetadataFieldsPanel(
              titleController: _titleController,
              originalTitleController: _originalTitleController,
              releaseDateController: _releaseDateController,
              runtimeController: _runtimeController,
              overviewController: _overviewController,
              metadataStatus: _metadataStatus,
              saving: _saving,
              onStatusChanged:
                  (value) =>
                      setState(() => _metadataStatus = value ?? 'MANUAL'),
              onCancel: _saving ? null : () => context.go('/video'),
              onSave: _saving ? null : _save,
            );
            if (!wide) {
              return Column(
                children: [coverPanel, const SizedBox(height: 18), formPanel],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 360, child: coverPanel),
                const SizedBox(width: 20),
                Expanded(child: formPanel),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showMessage(AppLocalizations.of(context).videoTitleRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      final minutes = int.tryParse(_runtimeController.text.trim());
      await ref
          .read(movieCenterControllerProvider.notifier)
          .updateMetadata(
            videoItemId: widget.item.id,
            title: title,
            originalTitle: _blankToNull(_originalTitleController.text),
            releaseDate: DateTime.tryParse(_releaseDateController.text.trim()),
            overview: _blankToNull(_overviewController.text),
            posterFileId: _blankToNull(_posterFileIdController.text),
            backdropFileId: _blankToNull(_backdropFileIdController.text),
            runtimeSeconds:
                minutes == null || minutes <= 0 ? null : minutes * 60,
            metadataStatus: _metadataStatus,
          );
      if (!mounted) {
        return;
      }
      ref.invalidate(movieDetailProvider(widget.item.id));
      ref.invalidate(movieCenterControllerProvider);
      _showMessage(AppLocalizations.of(context).videoMetadataSaved);
      context.go('/video');
    } catch (error) {
      if (mounted) {
        _showMessage(movieErrorMessage(error), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _blankToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showMessage(String message, {bool isError = false}) {
    showMovieFeedback(context, message, isError: isError);
  }
}

class _EditHeader extends StatelessWidget {
  const _EditHeader({required this.item});

  final MovieVideoItem item;

  @override
  Widget build(BuildContext context) {
    return WorkbenchPanel(
      padding: EdgeInsets.all(26),
      backgroundColor: context.videoColors.surfaceContainerLow,
      child: Row(
        children: [
          _MiniPoster(item: item),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InfoPill(label: item.mediaType),
                    _InfoPill(label: item.year),
                    _InfoPill(label: item.runtimeText),
                  ],
                ),
                SizedBox(height: 12),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.videoColors.onSurface,
                    fontSize: 30,
                    height: 38 / 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context).videoEditMetadataDesc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.videoColors.onSurfaceVariant,
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CoverEditPanel extends StatelessWidget {
  const _CoverEditPanel({
    required this.item,
    required this.posterFileIdController,
    required this.backdropFileIdController,
  });

  final MovieVideoItem item;
  final TextEditingController posterFileIdController;
  final TextEditingController backdropFileIdController;

  @override
  Widget build(BuildContext context) {
    return _PanelContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.of(context).videoCoverAssets,
            style: TextStyle(
              color: context.videoColors.onSurface,
              fontSize: 18,
              height: 24 / 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 190,
              height: 285,
              child: _PosterPreview(item: item),
            ),
          ),
          SizedBox(height: 16),
          _BackdropPreview(item: item),
          SizedBox(height: 20),
          _TextInput(
            label: AppLocalizations.of(context).videoPosterFileId,
            controller: posterFileIdController,
          ),
          SizedBox(height: 14),
          _TextInput(
            label: AppLocalizations.of(context).videoBackdropFileId,
            controller: backdropFileIdController,
          ),
          SizedBox(height: 14),
          Text(
            AppLocalizations.of(context).videoCoverIdHint,
            style: TextStyle(
              color: context.videoColors.onSurfaceVariant.withValues(
                alpha: 0.72,
              ),
              fontSize: 12,
              height: 18 / 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataFieldsPanel extends StatelessWidget {
  const _MetadataFieldsPanel({
    required this.titleController,
    required this.originalTitleController,
    required this.releaseDateController,
    required this.runtimeController,
    required this.overviewController,
    required this.metadataStatus,
    required this.saving,
    required this.onStatusChanged,
    required this.onCancel,
    required this.onSave,
  });

  final TextEditingController titleController;
  final TextEditingController originalTitleController;
  final TextEditingController releaseDateController;
  final TextEditingController runtimeController;
  final TextEditingController overviewController;
  final String metadataStatus;
  final bool saving;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return _PanelContainer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final statusField = DropdownButtonFormField<String>(
            // ignore: deprecated_member_use — controlled dropdown requires `value`
            value: metadataStatus,
            dropdownColor: context.videoColors.surfaceContainerHighest,
            decoration: _inputDecoration(
              context,
              AppLocalizations.of(context).videoMetadataStatus,
            ),
            style: TextStyle(
              color: context.videoColors.onSurface,
              fontSize: 14,
            ),
            items: [
              DropdownMenuItem(
                value: 'MANUAL',
                child: Text(AppLocalizations.of(context).videoManualLock),
              ),
              DropdownMenuItem(
                value: 'MATCHED',
                child: Text(AppLocalizations.of(context).videoMatched),
              ),
              DropdownMenuItem(
                value: 'PENDING',
                child: Text(
                  AppLocalizations.of(context).videoPendingRecognition,
                ),
              ),
              DropdownMenuItem(
                value: 'FAILED',
                child: Text(
                  AppLocalizations.of(context).videoRecognitionFailed,
                ),
              ),
            ],
            onChanged: onStatusChanged,
          );

          return Column(
            children: [
              if (compact) ...[
                _TextInput(
                  label: AppLocalizations.of(context).videoSortTitle,
                  controller: titleController,
                ),
                const SizedBox(height: 16),
                _TextInput(
                  label: AppLocalizations.of(context).videoOriginalTitle,
                  controller: originalTitleController,
                ),
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _TextInput(
                        label: AppLocalizations.of(context).videoSortTitle,
                        controller: titleController,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _TextInput(
                        label: AppLocalizations.of(context).videoOriginalTitle,
                        controller: originalTitleController,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              if (compact) ...[
                _TextInput(
                  label: AppLocalizations.of(context).videoReleaseDate,
                  hintText: '2026-05-21',
                  controller: releaseDateController,
                ),
                const SizedBox(height: 16),
                _TextInput(
                  label: AppLocalizations.of(context).videoRuntimeMinutes,
                  controller: runtimeController,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                statusField,
              ] else
                Row(
                  children: [
                    Expanded(
                      child: _TextInput(
                        label: AppLocalizations.of(context).videoReleaseDate,
                        hintText: '2026-05-21',
                        controller: releaseDateController,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _TextInput(
                        label: AppLocalizations.of(context).videoRuntimeMinutes,
                        controller: runtimeController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: statusField),
                  ],
                ),
              const SizedBox(height: 16),
              _TextInput(
                label: AppLocalizations.of(context).videoOverviewLabel,
                controller: overviewController,
                maxLines: 10,
              ),
              const SizedBox(height: 24),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton(
                    onPressed: onCancel,
                    style: _movieOutlinedButtonStyle(context),
                    child: Text(AppLocalizations.of(context).videoCancel),
                  ),
                  FilledButton.icon(
                    onPressed: onSave,
                    icon:
                        saving
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(Icons.save_rounded),
                    label: Text(AppLocalizations.of(context).videoSaveChanges),
                    style: _movieFilledButtonStyle(context),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PanelContainer extends StatelessWidget {
  const _PanelContainer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return WorkbenchPanel(
      padding: EdgeInsets.all(24),
      backgroundColor: context.videoColors.surfaceContainerLow,
      child: child,
    );
  }
}

class _MiniPoster extends StatelessWidget {
  const _MiniPoster({required this.item});

  final MovieVideoItem item;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 74, height: 104, child: _PosterPreview(item: item));
  }
}

class _PosterPreview extends StatelessWidget {
  const _PosterPreview({required this.item});

  final MovieVideoItem item;

  @override
  Widget build(BuildContext context) {
    final posterUrl = item.posterImageUrl;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.30),
        ),
        gradient: LinearGradient(
          colors: [
            context.videoColors.primaryContainer,
            context.videoColors.surfaceContainerHighest,
            context.videoColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (posterUrl != null && posterUrl.isNotEmpty)
            Image.network(
              posterUrl,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  context.videoColors.surface.withValues(alpha: 0.46),
                  context.videoColors.surface.withValues(alpha: 0.96),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: Icon(
              posterUrl != null && posterUrl.isNotEmpty
                  ? Icons.check_circle_rounded
                  : Icons.image_rounded,
              color: context.videoColors.onSurface.withValues(alpha: 0.72),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 16,
            child: Text(
              item.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.videoColors.onSurface,
                fontSize: 16,
                height: 20 / 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropPreview extends StatelessWidget {
  const _BackdropPreview({required this.item});

  final MovieVideoItem item;

  @override
  Widget build(BuildContext context) {
    final backdropUrl = item.backdropImageUrl;
    return Container(
      height: 120,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: context.videoColors.outlineVariant.withValues(alpha: 0.30),
        ),
        gradient: LinearGradient(
          colors: [
            context.videoColors.surfaceContainer,
            context.videoColors.surfaceContainerHigh,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child:
          backdropUrl != null && backdropUrl.isNotEmpty
              ? Image.network(
                backdropUrl,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => const _BackdropPlaceholder(),
              )
              : const _BackdropPlaceholder(),
    );
  }
}

class _BackdropPlaceholder extends StatelessWidget {
  const _BackdropPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wallpaper_rounded,
            color: context.videoColors.onSurfaceVariant.withValues(alpha: 0.56),
            size: 24,
          ),
          SizedBox(height: 4),
          Text(
            AppLocalizations.of(context).videoBackdrop,
            style: TextStyle(
              color: context.videoColors.onSurfaceVariant.withValues(
                alpha: 0.56,
              ),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.videoColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: context.videoColors.primary.withValues(alpha: 0.26),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: context.videoColors.primary,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.label,
    required this.controller,
    this.hintText,
    this.maxLines = 1,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String? hintText;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: context.videoColors.onSurface, fontSize: 14),
      decoration: _inputDecoration(context, label, hintText: hintText),
    );
  }
}

InputDecoration _inputDecoration(
  BuildContext context,
  String label, {
  String? hintText,
}) {
  final c = context.videoColors;
  return InputDecoration(
    labelText: label,
    hintText: hintText,
    labelStyle: TextStyle(color: c.onSurfaceVariant),
    hintStyle: TextStyle(color: c.onSurfaceVariant.withValues(alpha: 0.56)),
    filled: true,
    fillColor: c.surfaceContainerHigh.withValues(alpha: 0.44),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c.outlineVariant.withValues(alpha: 0.24)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c.outlineVariant.withValues(alpha: 0.24)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: c.primary),
    ),
  );
}

ButtonStyle _movieFilledButtonStyle(BuildContext context) {
  final c = context.videoColors;
  return FilledButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    backgroundColor: c.primaryContainer,
    foregroundColor: c.onPrimaryContainer,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );
}

ButtonStyle _movieOutlinedButtonStyle(BuildContext context) {
  final c = context.videoColors;
  return OutlinedButton.styleFrom(
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    foregroundColor: c.onSurface,
    side: BorderSide(color: c.outlineVariant.withValues(alpha: 0.46)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
  );
}
