import 'package:flutter/material.dart';

/// 非本机文件平台使用的应用背景图片存根。
class AppBackdropFileView extends StatelessWidget {
  const AppBackdropFileView({required this.path, required this.fit, super.key});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
