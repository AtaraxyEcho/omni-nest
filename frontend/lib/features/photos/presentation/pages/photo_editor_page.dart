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
    // 确定编辑类型和参数
    String editType;
    Map<String, dynamic> editParams;

    if (_cropRect != null) {
      editType = 'CROP';
      editParams = {
        'x': _cropRect!.left.round(),
        'y': _cropRect!.top.round(),
        'width': _cropRect!.width.round(),
        'height': _cropRect!.height.round(),
      };
    } else if (_rotation != 0) {
      editType = 'ROTATE';
      editParams = {'angle': _rotation};
    } else if (_brightness != 0) {
      editType = 'BRIGHTNESS';
      editParams = {'factor': _brightness};
    } else if (_contrast != 1) {
      editType = 'CONTRAST';
      editParams = {'factor': _contrast};
    } else if (_filter != FilterPreset.original) {
      editType = 'FILTER';
      editParams = {'filter': _filter.name};
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).photosNoChanges)),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(photoCenterControllerProvider.notifier)
          .applyEdit(photoId, editType, editParams);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).photosEditSaved)),
        );
        // 重置编辑状态
        setState(() {
          _rotation = 0;
          _brightness = 0;
          _contrast = 1;
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
    required this.onFilterSelected,
    required this.onSave,
    required this.onShowVersions,
  });

  final PhotoItem photo;
  final EditTool? selectedTool;
  final double brightness;
  final double contrast;
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
                          ? _CropOverlay(
                            imageUrl: photo.coverUrl!,
                            imageWidth: photo.width?.toDouble() ?? 1,
                            imageHeight: photo.height?.toDouble() ?? 1,
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
          selectedFilter: filter,
          onBrightnessChanged: onBrightnessChanged,
          onContrastChanged: onContrastChanged,
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
    // 亮度调整
    final b = brightness;
    // 对比度调整
    final c = contrast;
    // 基础矩阵（亮度 + 对比度）
    final matrix = <double>[
      c,
      0.0,
      0.0,
      0.0,
      b * 255,
      0.0,
      c,
      0.0,
      0.0,
      b * 255,
      0.0,
      0.0,
      c,
      0.0,
      b * 255,
      0.0,
      0.0,
      0.0,
      1.0,
      0.0,
    ];

    // 滤镜叠加
    switch (filter) {
      case FilterPreset.grayscale:
        return _applyGrayscale(matrix);
      case FilterPreset.sepia:
        return _applySepia(matrix);
      case FilterPreset.original:
      case FilterPreset.blur:
      case FilterPreset.sharpen:
        // blur/sharpen 需要 ConvolveOp，前端仅做颜色矩阵
        return matrix;
    }
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

class _CropOverlay extends StatefulWidget {
  const _CropOverlay({
    required this.imageUrl,
    required this.imageWidth,
    required this.imageHeight,
    required this.onConfirmed,
    required this.onCancelled,
  });

  final String imageUrl;
  final double imageWidth;
  final double imageHeight;
  final ValueChanged<Rect> onConfirmed;
  final VoidCallback onCancelled;

  @override
  State<_CropOverlay> createState() => _CropOverlayState();
}

class _CropOverlayState extends State<_CropOverlay> {
  Offset? _start;
  Offset? _end;
  final GlobalKey _imageKey = GlobalKey();

  Rect? get _cropRect {
    if (_start == null || _end == null) return null;
    final left = _start!.dx < _end!.dx ? _start!.dx : _end!.dx;
    final top = _start!.dy < _end!.dy ? _start!.dy : _end!.dy;
    final right = _start!.dx > _end!.dx ? _start!.dx : _end!.dx;
    final bottom = _start!.dy > _end!.dy ? _start!.dy : _end!.dy;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  Rect? _toImageCoords() {
    final rect = _cropRect;
    if (rect == null) return null;
    final renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final size = renderBox.size;
    // 将 widget 坐标转换为图片像素坐标
    final scaleX = widget.imageWidth / size.width;
    final scaleY = widget.imageHeight / size.height;
    return Rect.fromLTRB(
      (rect.left * scaleX).clamp(0, widget.imageWidth),
      (rect.top * scaleY).clamp(0, widget.imageHeight),
      (rect.right * scaleX).clamp(0, widget.imageWidth),
      (rect.bottom * scaleY).clamp(0, widget.imageHeight),
    );
  }

  void _onPanStart(DragStartDetails details) {
    final renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final local = renderBox.globalToLocal(details.globalPosition);
    setState(() {
      _start = local;
      _end = local;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final renderBox =
        _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final local = renderBox.globalToLocal(details.globalPosition);
    setState(() => _end = local);
  }

  void _confirm() {
    final imageRect = _toImageCoords();
    if (imageRect != null && imageRect.width > 10 && imageRect.height > 10) {
      widget.onConfirmed(imageRect);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Column(
      children: [
        // 操作栏
        Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.photosColors.surfaceContainer.withValues(
              alpha: 0.70,
            ),
          ),
          child: Row(
            children: [
              if (!compact) ...[
                Icon(
                  Icons.crop,
                  color: context.photosColors.onSurfaceVariant,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context).photosCropDragHint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.photosColors.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
              ] else
                const Spacer(),
              TextButton(
                onPressed: widget.onCancelled,
                child: Text(AppLocalizations.of(context).photosCancel),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _cropRect != null ? _confirm : null,
                child: Text(AppLocalizations.of(context).photosConfirmCrop),
              ),
            ],
          ),
        ),
        // 图片 + 裁剪遮罩
        Expanded(
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 图片
                Center(
                  child: CachedNetworkImage(
                    key: _imageKey,
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
                // 裁剪遮罩
                if (_cropRect != null)
                  CustomPaint(painter: _CropOverlayPainter(_cropRect!)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  _CropOverlayPainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    // 半透明遮罩
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.50);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRect(rect),
      ),
      overlayPaint,
    );
    // 裁剪框边框
    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawRect(rect, borderPaint);
    // 三分线
    final gridPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final thirdW = rect.width / 3;
    final thirdH = rect.height / 3;
    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(rect.left + thirdW * i, rect.top),
        Offset(rect.left + thirdW * i, rect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(rect.left, rect.top + thirdH * i),
        Offset(rect.right, rect.top + thirdH * i),
        gridPaint,
      );
    }
    // 四角手柄
    final handlePaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    const handleLen = 16.0;
    // 左上
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(handleLen, 0),
      handlePaint,
    );
    canvas.drawLine(
      rect.topLeft,
      rect.topLeft + const Offset(0, handleLen),
      handlePaint,
    );
    // 右上
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(-handleLen, 0),
      handlePaint,
    );
    canvas.drawLine(
      rect.topRight,
      rect.topRight + const Offset(0, handleLen),
      handlePaint,
    );
    // 左下
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(handleLen, 0),
      handlePaint,
    );
    canvas.drawLine(
      rect.bottomLeft,
      rect.bottomLeft + const Offset(0, -handleLen),
      handlePaint,
    );
    // 右下
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(-handleLen, 0),
      handlePaint,
    );
    canvas.drawLine(
      rect.bottomRight,
      rect.bottomRight + const Offset(0, -handleLen),
      handlePaint,
    );
  }

  @override
  bool shouldRepaint(_CropOverlayPainter oldDelegate) =>
      oldDelegate.rect != rect;
}
