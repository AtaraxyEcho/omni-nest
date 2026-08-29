import 'package:flutter/material.dart';
import 'package:omninest/core/widgets/skeleton_shimmer.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_control_layout.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_view_settings.dart';

/// 在正文实际位置呈现章节加载占位内容。
class ReaderContentSkeleton extends StatelessWidget {
  const ReaderContentSkeleton({required this.settings, super.key});

  final ReaderViewSettings settings;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        final layout = ReaderControlLayout.resolve(
          viewport: viewport,
          fontSize: settings.fontSize,
          textScale: MediaQuery.textScalerOf(context).scale(1),
        );
        final topPadding = layout.isShort ? 28.0 : 72.0;

        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            layout.horizontalPadding,
            topPadding,
            layout.horizontalPadding,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: layout.textColumnWidth),
              child: SkeletonShimmer(
                child: Column(
                  key: const Key('readerContentSkeleton'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _line(context, widthFactor: 0.46, height: 28),
                    const SizedBox(height: 14),
                    _line(context, widthFactor: 0.24, height: 12),
                    SizedBox(height: layout.isShort ? 28 : 48),
                    ..._paragraph(context, const [1, 0.96, 0.82]),
                    const SizedBox(height: 30),
                    ..._paragraph(context, const [0.93, 1, 0.88, 0.64]),
                    const SizedBox(height: 30),
                    ..._paragraph(context, const [1, 0.91, 0.76]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _paragraph(BuildContext context, List<double> widths) {
    return [
      for (var index = 0; index < widths.length; index++) ...[
        FractionallySizedBox(
          widthFactor: widths[index],
          child: _line(context, height: 15),
        ),
        if (index < widths.length - 1) const SizedBox(height: 14),
      ],
    ];
  }

  Widget _line(
    BuildContext context, {
    double? widthFactor,
    required double height,
  }) {
    final line = DecoratedBox(
      decoration: BoxDecoration(
        color: settings.onSurfaceColor.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(4),
      ),
      child: SizedBox(height: height),
    );
    if (widthFactor == null) {
      return SizedBox(width: double.infinity, child: line);
    }
    return FractionallySizedBox(widthFactor: widthFactor, child: line);
  }
}
