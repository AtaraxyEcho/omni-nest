import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 展示具有桌面端宽度上限的阅读模块提示条。
void showReaderSnackBar(
  BuildContext context,
  String message, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
}) {
  final viewportWidth = MediaQuery.sizeOf(context).width;
  final width =
      viewportWidth >= 600 ? math.min(560.0, viewportWidth - 48) : null;
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        action: action,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        width: width,
      ),
    );
}
