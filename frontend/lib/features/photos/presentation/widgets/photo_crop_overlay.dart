import 'package:flutter/material.dart';

import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';

/// 照片裁剪覆盖层：图片与手势层共用同一个确定性绘制盒子。
///
/// 图片按 contain 留在绘制区内，裁剪框直接拖拽绘制；确认时把覆盖层内的
/// 局部坐标线性映射回原图像素坐标——绘制盒子的宽高完全由
/// [imageWidth]/[imageHeight] 与可用空间决定，不依赖图片组件的内部布局。
class PhotoCropOverlay extends StatefulWidget {
  const PhotoCropOverlay({
    required this.imageWidth,
    required this.imageHeight,
    required this.preview,
    required this.onConfirmed,
    required this.onCancelled,
    super.key,
  });

  /// 原图像素宽度。
  final double imageWidth;

  /// 原图像素高度。
  final double imageHeight;

  /// 图片预览组件（将按 contain 等比放入绘制盒子）。
  final Widget preview;

  /// 确认裁剪，返回原图像素坐标下的裁剪框。
  final ValueChanged<Rect> onConfirmed;
  final VoidCallback onCancelled;

  @override
  State<PhotoCropOverlay> createState() => _PhotoCropOverlayState();
}

class _PhotoCropOverlayState extends State<PhotoCropOverlay> {
  Offset? _start;
  Offset? _end;

  Rect? get _cropRect {
    final start = _start;
    final end = _end;
    if (start == null || end == null) return null;
    final left = start.dx < end.dx ? start.dx : end.dx;
    final top = start.dy < end.dy ? start.dy : end.dy;
    final right = start.dx > end.dx ? start.dx : end.dx;
    final bottom = start.dy > end.dy ? start.dy : end.dy;
    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _onPanStart(DragStartDetails details) {
    final box = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(details.globalPosition);
    setState(() {
      _start = local;
      _end = local;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() => _end = box.globalToLocal(details.globalPosition));
  }

  void _confirm() {
    final rect = _cropRect;
    final box = _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    if (rect == null || box == null) return;
    if (rect.width < 10 || rect.height < 10) return;
    final scale = widget.imageWidth / box.size.width;
    final scaleVertical = widget.imageHeight / box.size.height;
    final imageRect = Rect.fromLTRB(
      (rect.left * scale).clamp(0.0, widget.imageWidth),
      (rect.top * scaleVertical).clamp(0.0, widget.imageHeight),
      (rect.right * scale).clamp(0.0, widget.imageWidth),
      (rect.bottom * scaleVertical).clamp(0.0, widget.imageHeight),
    );
    widget.onConfirmed(imageRect);
  }

  final GlobalKey _surfaceKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Column(
      children: [
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final fitted = applyBoxFit(
                BoxFit.contain,
                Size(widget.imageWidth, widget.imageHeight),
                constraints.biggest,
              );
              final drawn = fitted.destination;
              final offsetX = (constraints.maxWidth - drawn.width) / 2;
              final offsetY = (constraints.maxHeight - drawn.height) / 2;
              return Stack(
                children: [
                  Positioned(
                    left: offsetX,
                    top: offsetY,
                    width: drawn.width,
                    height: drawn.height,
                    child: widget.preview,
                  ),
                  Positioned(
                    left: offsetX,
                    top: offsetY,
                    width: drawn.width,
                    height: drawn.height,
                    child: GestureDetector(
                      key: _surfaceKey,
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _onPanStart,
                      onPanUpdate: _onPanUpdate,
                      child: CustomPaint(painter: _CropMaskPainter(_cropRect)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CropMaskPainter extends CustomPainter {
  _CropMaskPainter(this.rect);

  final Rect? rect;

  @override
  void paint(Canvas canvas, Size size) {
    final crop = rect;
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.50);
    if (crop == null) {
      canvas.drawRect(Offset.zero & size, overlayPaint);
      return;
    }
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRect(crop),
      ),
      overlayPaint,
    );
    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
    canvas.drawRect(crop, borderPaint);
    final gridPaint =
        Paint()
          ..color = Colors.white.withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
    final thirdW = crop.width / 3;
    final thirdH = crop.height / 3;
    for (int i = 1; i <= 2; i++) {
      canvas.drawLine(
        Offset(crop.left + thirdW * i, crop.top),
        Offset(crop.left + thirdW * i, crop.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(crop.left, crop.top + thirdH * i),
        Offset(crop.right, crop.top + thirdH * i),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CropMaskPainter oldDelegate) => oldDelegate.rect != rect;
}
