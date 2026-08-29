import 'package:flutter/material.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:omninest/features/video/presentation/widgets/movie_responsive_layout.dart';

/// 影片详情独立页面框架。
class MovieDetailPageFrame extends StatelessWidget {
  const MovieDetailPageFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.videoColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = switch (constraints.maxWidth) {
              < 600 => 16.0,
              < 1000 => 24.0,
              < 1600 => 32.0,
              _ => 40.0,
            };
            final availableWidth = constraints.maxWidth - horizontalPadding * 2;
            final contentWidth =
                availableWidth
                    .clamp(0.0, movieDesktopContentMaxWidth)
                    .toDouble();
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                48,
              ),
              child: Center(child: SizedBox(width: contentWidth, child: child)),
            );
          },
        ),
      ),
    );
  }
}
