import 'package:cached_network_image/cached_network_image.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/core/navigation/navigation_extensions.dart';
import 'package:omninest/core/widgets/app_error_view.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_editor_top_bar.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_crop_overlay.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_editor_toolbar.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_version_list_sheet.dart';

/// 照片编辑页面
class PhotoEditorPage extends ConsumerStatefulWidget {
  const PhotoEditorPage({required this.photoId, super.key});

  final String photoId;

  @override
  ConsumerState<PhotoEditorPage> createState() => _PhotoEditorPageState();
}

class _PhotoEditorPageState extends ConsumerState<PhotoEditorPage> {
  EditTool? _selectedTool;
  double _brightness = 0;
  double _contrast = 1;
  double _saturation = 0;
  FilterPreset _filter = FilterPreset.original;
  double _rotation = 0;
  bool _saving = false;
  bool _cropMode = false;
  Rect? _cropRect;

  @override
  Widget build(BuildContext context) {
    final photoAsync = ref.watch(photoDetailProvider(widget.photoId));
    return Scaffold(
      backgroundColor: context.photosColors.surface,
      body: photoAsync.when(
        data:
            (photo) => _EditorBody(
              photo: photo,
              saturation: _saturation,
              selectedTool: _selectedTool,
              brightness: _brightness,
              contrast: _contrast,
              filter: _filter,
              rotation: _rotation,
              saving: _saving,
              cropMode: _cropMode,
              onToolSelected: (tool) => setState(() => _selectedTool = tool),
              onRotate:
                  () => setState(() => _rotation = (_rotation + 90) % 360),
              onCrop: () => _showCropMessage(context),
              onCropConfirmed: _onCropConfirmed,
              onCropCancelled: _onCropCancelled,
              onBrightnessChanged: (v) => setState(() => _brightness = v),
              onContrastChanged: (v) => setState(() => _contrast = v),
              onSaturationChanged: (v) => setState(() => _saturation = v),
              onFilterSelected: (f) => setState(() => _filter = f),
              onSave: () => _saveEdit(context, ref, widget.photoId),
              onShowVersions: () => _showVersions(context, ref, widget.photoId),
            ),
        error:
            (error, _) => AppErrorView(
              message: describeUserFacingError(error).displayMessage,
              onRetry:
                  () => ref.invalidate(photoDetailProvider(widget.photoId)),
            ),
        loading: () => const AppLoading.detail(),
      ),
    );
  }

  void _showCropMessage(BuildContext context) {
    setState(() {
      _cropMode = true;
      _cropRect = null;
    });
  }

  void _onCropConfirmed(Rect cropRect) {
    setState(() {
      _cropMode = false;
      _cropRect = cropRect;
    });
  }

  void _onCropCancelled() {
    setState(() {
      _cropMode = false;
      _cropRect = null;
    });
  }

  Future<void> _saveEdit(
    BuildContext context,
    WidgetRef ref,
    String photoId,
  ) async {
    // 收集全部非默认调整，按几何在前、颜色在后的顺序逐个提交。
    final edits = <(String, Map<String, dynamic>)>[
      if (_cropRect != null)
        (
          'CROP',
          {
            'x': _cropRect!.left.round(),
            'y': _cropRect!.top.round(),
            'width': _cropRect!.width.round(),
            'height': _cropRect!.height.round(),
          },
        ),
      if (_rotation != 0) ('ROTATE', {'angle': _rotation}),
      // 后端 BRIGHTNESS 为乘法系数：滑杆 -1..1 映射为 0..2。
      if (_brightness != 0) ('BRIGHTNESS', {'factor': 1 + _brightness}),
      if (_contrast != 1) ('CONTRAST', {'factor': _contrast}),
      if (_saturation != 0) ('SATURATION', {'factor': 1 + _saturation}),
      // 后端按 name 读取滤镜名：grayscale/sepia/blur/sharpen。
      if (_filter != FilterPreset.original) ('FILTER', {'name': _filter.name}),
    ];

    if (edits.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).photosNoChanges)),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final notifier = ref.read(photoCenterControllerProvider.notifier);
      for (final (editType, editParams) in edits) {
        await notifier.applyEdit(photoId, editType, editParams);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).photosEditSaved)),
        );
        // 重置编辑状态
        setState(() {
          _rotation = 0;
          _brightness = 0;
          _contrast = 1;
          _saturation = 0;
          _filter = FilterPreset.original;
          _selectedTool = null;
          _cropRect = null;
          _cropMode = false;
        });
        ref.invalidate(photoDetailProvider(photoId));
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).photosSaveFailed),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showVersions(
    BuildContext context,
    WidgetRef ref,
    String photoId,
  ) async {
    final versions = await ref
        .read(photoCenterControllerProvider.notifier)
        .listVersions(photoId);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.photosColors.surfaceContainerHigh,
      builder:
          (ctx) => PhotoVersionListSheet(
            versions: versions,
            onRevert: (versionId) async {
              Navigator.pop(ctx);
              try {
                await ref
                    .read(photoCenterControllerProvider.notifier)
                    .revertToVersion(photoId, versionId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context).photosRolledBack,
                      ),
                    ),
                  );
                  ref.invalidate(photoDetailProvider(photoId));
                }
              } on Exception {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppLocalizations.of(context).photosRollbackFailed,
                      ),
                    ),
                  );
                }
              }
            },
          ),
    );
  }
}

class _EditorBody extends StatelessWidget {
  const _EditorBody({
    required this.photo,
    required this.selectedTool,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.filter,
    required this.rotation,
    required this.saving,
    required this.cropMode,
    required this.onToolSelected,
    required this.onRotate,
    required this.onCrop,
    required this.onCropConfirmed,
    required this.onCropCancelled,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onSaturationChanged,
    required this.onFilterSelected,
    required this.onSave,
    required this.onShowVersions,
  });

  final PhotoItem photo;
  final EditTool? selectedTool;
  final double brightness;
  final double contrast;
  final double saturation;
  final FilterPreset filter;
  final double rotation;
  final bool saving;
  final bool cropMode;
  final ValueChanged<EditTool?> onToolSelected;
  final VoidCallback onRotate;
  final VoidCallback onCrop;
  final ValueChanged<Rect> onCropConfirmed;
  final VoidCallback onCropCancelled;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<FilterPreset> onFilterSelected;
  final VoidCallback onSave;
  final VoidCallback onShowVersions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部栏
        PhotoEditorTopBar(
          photo: photo,
          saving: saving,
          onBack: () => context.popOrGo('/photos/${photo.id}'),
          onSave: onSave,
          onShowVersions: onShowVersions,
        ),
        // 图片编辑区
        Expanded(
          child: Container(
            color: context.photosColors.surfaceContainerLow,
            child: Center(
              child:
                  photo.hasCover
                      ? cropMode
                          ? PhotoCropOverlay(
                            imageWidth: photo.width?.toDouble() ?? 1,
                            imageHeight: photo.height?.toDouble() ?? 1,
                            preview: CachedNetworkImage(
                              imageUrl: photo.coverUrl!,
                              fit: BoxFit.contain,
                            ),
                            onConfirmed: onCropConfirmed,
                            onCancelled: onCropCancelled,
                          )
                          : _buildEditableImage()
                      : Icon(
                        Icons.photo_outlined,
                        color: context.photosColors.onSurfaceVariant,
                        size: 64,
                      ),
            ),
          ),
        ),
        // 工具栏
        PhotoEditorToolbar(
          selectedTool: selectedTool,
          onToolSelected: onToolSelected,
          onRotate: onRotate,
          onCrop: onCrop,
          brightness: brightness,
          contrast: contrast,
          saturation: saturation,
          selectedFilter: filter,
          onBrightnessChanged: onBrightnessChanged,
          onContrastChanged: onContrastChanged,
          onSaturationChanged: onSaturationChanged,
          onFilterSelected: onFilterSelected,
        ),
      ],
    );
  }

  Widget _buildEditableImage() {
    // 构建颜色滤镜矩阵
    final colorMatrix = _buildColorMatrix();

    return Transform.rotate(
      angle: rotation * 3.14159265 / 180,
      child: ColorFiltered(
        colorFilter: ColorFilter.matrix(colorMatrix),
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: CachedNetworkImage(
            imageUrl: photo.coverUrl!,
            fit: BoxFit.contain,
            placeholder:
                (context, url) => Center(child: CircularProgressIndicator()),
            errorWidget:
                (context, url, error) => Icon(
                  Icons.broken_image_outlined,
                  color: context.photosColors.onSurfaceVariant,
                  size: 48,
                ),
          ),
        ),
      ),
    );
  }

  List<double> _buildColorMatrix() {
    // 与后端保存语义对齐：亮度为乘法系数 (1+b)，对比度为 (v-128)*c+128。
    final brightnessScale = 1 + brightness;
    final c = contrast;
    final scale = c * brightnessScale;
    final offset = 128 * (1 - c);
    final matrix = <double>[
      scale,
      0.0,
      0.0,
      0.0,
      offset,
      0.0,
      scale,
      0.0,
      0.0,
      offset,
      0.0,
      0.0,
      scale,
      0.0,
      offset,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];

    // 滤镜与饱和度叠加
    switch (filter) {
      case FilterPreset.grayscale:
        return _applyGrayscale(_applySaturation(matrix));
      case FilterPreset.sepia:
        return _applySepia(_applySaturation(matrix));
      case FilterPreset.original:
        return _applySaturation(matrix);
    }
  }

  /// 饱和度矩阵：out = gray + f * (in - gray)，f = 1 + saturation。
  List<double> _applySaturation(List<double> m) {
    final f = 1 + saturation;
    const lr = 0.299;
    const lg = 0.587;
    const lb = 0.114;
    // 灰度行对输入像素的合成系数
    final grayR = lr * m[0] + lg * m[5] + lb * m[10];
    final grayG = lr * m[1] + lg * m[6] + lb * m[11];
    final grayB = lr * m[2] + lg * m[7] + lb * m[12];
    return <double>[
      f * m[0] + (1 - f) * grayR,
      f * m[1] + (1 - f) * grayG,
      f * m[2] + (1 - f) * grayB,
      0.0,
      m[4],
      f * m[5] + (1 - f) * grayR,
      f * m[6] + (1 - f) * grayG,
      f * m[7] + (1 - f) * grayB,
      0.0,
      m[9],
      f * m[10] + (1 - f) * grayR,
      f * m[11] + (1 - f) * grayG,
      f * m[12] + (1 - f) * grayB,
      0.0,
      m[14],
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  List<double> _applyGrayscale(List<double> m) {
    // 灰度 = 0.299R + 0.587G + 0.114B
    return <double>[
      m[0] * 0.299,
      m[1] * 0.587,
      m[2] * 0.114,
      0.0,
      m[4],
      m[5] * 0.299,
      m[6] * 0.587,
      m[7] * 0.114,
      0.0,
      m[9],
      m[10] * 0.299,
      m[11] * 0.587,
      m[12] * 0.114,
      0.0,
      m[14],
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }

  List<double> _applySepia(List<double> m) {
    return <double>[
      m[0] * 0.393 + m[1] * 0.769 + m[2] * 0.189,
      m[0] * 0.349 + m[1] * 0.686 + m[2] * 0.168,
      m[0] * 0.272 + m[1] * 0.534 + m[2] * 0.131,
      0.0,
      m[4],
      m[5] * 0.393 + m[6] * 0.769 + m[7] * 0.189,
      m[5] * 0.349 + m[6] * 0.686 + m[7] * 0.168,
      m[5] * 0.272 + m[6] * 0.534 + m[7] * 0.131,
      0.0,
      m[9],
      m[10] * 0.393 + m[11] * 0.769 + m[12] * 0.189,
      m[10] * 0.349 + m[11] * 0.686 + m[12] * 0.168,
      m[10] * 0.272 + m[11] * 0.534 + m[12] * 0.131,
      0.0,
      m[14],
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];
  }
}
