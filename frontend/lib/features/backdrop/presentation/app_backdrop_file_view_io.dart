import 'dart:io';

import 'package:flutter/material.dart';

/// IO 平台使用的本机背景图片，包括桌面端和移动端。
class AppBackdropFileView extends StatelessWidget {
  const AppBackdropFileView({required this.path, required this.fit, super.key});

  final String path;
  final BoxFit fit;

  int? _resolveCacheExtent(double extent, double devicePixelRatio) {
    if (!extent.isFinite || extent <= 0 || !devicePixelRatio.isFinite) {
      return null;
    }
    final value = (extent * devicePixelRatio).round();
    return value.clamp(1, 8192);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        final cacheWidth = _resolveCacheExtent(
          constraints.maxWidth,
          devicePixelRatio,
        );
        final cacheHeight = _resolveCacheExtent(
          constraints.maxHeight,
          devicePixelRatio,
        );
        return Image.file(
          File(path),
          width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          fit: fit,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
          isAntiAlias: true,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        );
      },
    );
  }
}
