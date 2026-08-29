import 'package:flutter/material.dart';
import 'package:omninest/core/widgets/skeleton_shimmer.dart';

/// 内容骨架的结构类型。
enum AppLoadingLayout { list, grid, detail }

/// 在实际内容区域内展示的通用加载骨架。
class AppLoading extends StatelessWidget {
  const AppLoading({super.key})
    : _simple = false,
      layout = AppLoadingLayout.list,
      gridAspectRatio = 1;

  const AppLoading.grid({this.gridAspectRatio = 1, super.key})
    : assert(gridAspectRatio > 0),
      _simple = false,
      layout = AppLoadingLayout.grid;

  const AppLoading.detail({super.key})
    : _simple = false,
      layout = AppLoadingLayout.detail,
      gridAspectRatio = 1;

  const AppLoading.simple({super.key})
    : _simple = true,
      layout = AppLoadingLayout.list,
      gridAspectRatio = 1;

  final bool _simple;
  final AppLoadingLayout layout;
  final double gridAspectRatio;

  @override
  Widget build(BuildContext context) {
    if (_simple) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        return SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 28,
            compact ? 16 : 24,
            compact ? 16 : 28,
            32,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1320),
              child: SkeletonShimmer(
                child: switch (layout) {
                  AppLoadingLayout.list => const _ListContentSkeleton(),
                  AppLoadingLayout.grid => _GridContentSkeleton(
                    aspectRatio: gridAspectRatio,
                  ),
                  AppLoadingLayout.detail => const _DetailContentSkeleton(),
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ListContentSkeleton extends StatelessWidget {
  const _ListContentSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 7; index++) ...[
          _ListRowSkeleton(short: index == 2 || index == 5),
          if (index < 6) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ListRowSkeleton extends StatelessWidget {
  const _ListRowSkeleton({required this.short});

  final bool short;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SkeletonBox(width: 48, height: 48, borderRadius: 8),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FractionallySizedBox(
                  widthFactor: short ? 0.48 : 0.72,
                  child: const SkeletonBox(height: 14, borderRadius: 5),
                ),
                const SizedBox(height: 10),
                const FractionallySizedBox(
                  widthFactor: 0.32,
                  child: SkeletonBox(height: 10, borderRadius: 5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const SkeletonBox(width: 36, height: 20, borderRadius: 5),
        ],
      ),
    );
  }
}

class _GridContentSkeleton extends StatelessWidget {
  const _GridContentSkeleton({required this.aspectRatio});

  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = switch (constraints.maxWidth) {
          < 420 => 2,
          < 760 => 3,
          < 1100 => 4,
          _ => 5,
        };
        const spacing = 14.0;
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: 20,
          children: [
            for (var index = 0; index < columns * 2; index++)
              SizedBox(
                width: itemWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(
                      width: itemWidth,
                      height: itemWidth / aspectRatio,
                      borderRadius: 8,
                    ),
                    const SizedBox(height: 10),
                    const FractionallySizedBox(
                      widthFactor: 0.78,
                      child: SkeletonBox(height: 13, borderRadius: 5),
                    ),
                    const SizedBox(height: 8),
                    const FractionallySizedBox(
                      widthFactor: 0.46,
                      child: SkeletonBox(height: 10, borderRadius: 5),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DetailContentSkeleton extends StatelessWidget {
  const _DetailContentSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final mediaWidth = compact ? constraints.maxWidth : 280.0;
        final media = SkeletonBox(
          width: mediaWidth,
          height: compact ? mediaWidth * 0.62 : 360,
          borderRadius: 8,
        );
        const information = _DetailInformationSkeleton();
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [media, const SizedBox(height: 24), information],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            media,
            const SizedBox(width: 30),
            const Expanded(child: information),
          ],
        );
      },
    );
  }
}

class _DetailInformationSkeleton extends StatelessWidget {
  const _DetailInformationSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FractionallySizedBox(
          widthFactor: 0.72,
          child: SkeletonBox(height: 24, borderRadius: 6),
        ),
        SizedBox(height: 16),
        FractionallySizedBox(
          widthFactor: 0.42,
          child: SkeletonBox(height: 13, borderRadius: 5),
        ),
        SizedBox(height: 28),
        SkeletonBox(height: 12, borderRadius: 5),
        SizedBox(height: 11),
        SkeletonBox(height: 12, borderRadius: 5),
        SizedBox(height: 11),
        FractionallySizedBox(
          widthFactor: 0.82,
          child: SkeletonBox(height: 12, borderRadius: 5),
        ),
        SizedBox(height: 30),
        Row(
          children: [
            SkeletonBox(width: 104, height: 38, borderRadius: 7),
            SizedBox(width: 12),
            SkeletonBox(width: 104, height: 38, borderRadius: 7),
          ],
        ),
      ],
    );
  }
}
