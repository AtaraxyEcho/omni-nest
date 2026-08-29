import 'package:flutter/material.dart';

/// 为内容骨架提供横向扫光动画。
class SkeletonShimmer extends StatefulWidget {
  const SkeletonShimmer({required this.child, super.key});

  final Widget child;

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = Colors.white.withValues(alpha: dark ? 0.10 : 0.34);
    final highlightColor = Colors.white.withValues(alpha: dark ? 0.22 : 0.68);
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback:
              (bounds) => LinearGradient(
                colors: [baseColor, highlightColor, baseColor],
                stops: const [0, 0.5, 1],
                begin: const Alignment(-1, -0.2),
                end: const Alignment(1, 0.2),
                transform: _SlidingGradientTransform(
                  progress: _controller.value,
                ),
              ).createShader(bounds),
          child: child,
        );
      },
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.progress});

  final double progress;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (progress * 2 - 1), 0, 0);
  }
}

/// 内容骨架中的矩形占位块。
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final alpha = Theme.of(context).brightness == Brightness.dark ? 0.14 : 0.10;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.onSurface.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: SizedBox(width: width, height: height),
    );
  }
}
