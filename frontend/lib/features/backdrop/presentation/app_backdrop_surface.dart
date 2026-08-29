import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:omninest/core/utils/platform_helper.dart';
import 'package:omninest/features/backdrop/application/app_backdrop_video_session.dart';
import 'package:omninest/features/backdrop/domain/app_backdrop.dart';
import 'package:omninest/features/backdrop/domain/app_backdrop_policy.dart';
import 'package:omninest/features/backdrop/presentation/app_backdrop_file_view.dart';

/// 应用级本机背景渲染层。
class AppBackdropSurface extends ConsumerStatefulWidget {
  const AppBackdropSurface({
    required this.asset,
    required this.settings,
    required this.policy,
    required this.active,
    super.key,
  });

  final AppBackdropAsset? asset;
  final AppBackdropSettings settings;
  final AppBackdropPolicy policy;
  final bool active;

  @override
  ConsumerState<AppBackdropSurface> createState() => _AppBackdropSurfaceState();
}

class _AppBackdropSurfaceState extends ConsumerState<AppBackdropSurface>
    with WidgetsBindingObserver {
  bool? _lastLayoutUsable;
  String? _lastSessionSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(appBackdropVideoSessionProvider).updateLifecycleState(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = widget.asset;
    final fit =
        widget.settings.fit == AppBackdropFit.cover
            ? BoxFit.cover
            : BoxFit.contain;
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final canPlayVideo =
        !isWebPlatform &&
        asset?.isVideo == true &&
        !animationsDisabled &&
        widget.policy.motionAllowed;
    return LayoutBuilder(
      builder: (context, constraints) {
        final hasUsableLayout =
            constraints.maxWidth.isFinite &&
            constraints.maxHeight.isFinite &&
            constraints.maxWidth > 1 &&
            constraints.maxHeight > 1;
        final videoActive =
            widget.active && hasUsableLayout && canPlayVideo && asset != null;
        _syncSession(
          path: canPlayVideo ? asset?.path : null,
          muted: widget.settings.videoMuted,
          active: videoActive,
          layoutUsable: hasUsableLayout,
        );
        final media = _buildMedia(
          asset: asset,
          fit: fit,
          canPlayVideo: canPlayVideo,
        );
        final shouldBlurStatic =
            widget.settings.blurAmount > 0.05 && asset?.isVideo != true;
        final mediaLayer =
            shouldBlurStatic
                ? ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: widget.settings.blurAmount,
                    sigmaY: widget.settings.blurAmount,
                  ),
                  child: media,
                )
                : media;
        return ExcludeSemantics(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: Colors.transparent, child: mediaLayer),
                  if (widget.settings.dimAmount > 0.01)
                    ColoredBox(
                      color: Colors.black.withValues(
                        alpha: widget.settings.dimAmount,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMedia({
    required AppBackdropAsset? asset,
    required BoxFit fit,
    required bool canPlayVideo,
  }) {
    if (asset == null || asset.missing) {
      return const _AppBackdropFallback();
    }
    if (!asset.isVideo) {
      return AppBackdropFileView(path: asset.path, fit: fit);
    }
    if (!canPlayVideo) {
      return _AppBackdropVideoFallback(
        fit: fit,
        fallbackPath: asset.thumbnailPath,
      );
    }
    final session = ref.watch(appBackdropVideoSessionProvider);
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final controller = session.controller;
        if (session.openError != null || !session.ready || controller == null) {
          return _AppBackdropVideoFallback(
            fit: fit,
            fallbackPath: asset.thumbnailPath,
          );
        }
        return RepaintBoundary(
          child: Video(
            controller: controller,
            fit: fit,
            controls: NoVideoControls,
            wakelock: false,
            pauseUponEnteringBackgroundMode: true,
            resumeUponEnteringForegroundMode: true,
          ),
        );
      },
    );
  }

  void _syncSession({
    required String? path,
    required bool muted,
    required bool active,
    required bool layoutUsable,
  }) {
    final signature = '$path:$muted:$active:$layoutUsable';
    if (_lastSessionSignature == signature &&
        _lastLayoutUsable == layoutUsable) {
      return;
    }
    _lastSessionSignature = signature;
    _lastLayoutUsable = layoutUsable;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final session = ref.read(appBackdropVideoSessionProvider);
      session.setLayoutUsable(layoutUsable);
      session.configure(path: path, muted: muted, active: active);
    });
  }
}

class _AppBackdropVideoFallback extends StatelessWidget {
  const _AppBackdropVideoFallback({required this.fit, this.fallbackPath});

  final BoxFit fit;
  final String? fallbackPath;

  @override
  Widget build(BuildContext context) {
    final path = fallbackPath?.trim();
    if (path != null && path.isNotEmpty) {
      return AppBackdropFileView(path: path, fit: fit);
    }
    return const _AppBackdropFallback(icon: Icons.movie_creation_outlined);
  }
}

class _AppBackdropFallback extends StatelessWidget {
  const _AppBackdropFallback({this.icon = Icons.landscape_outlined});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1821), Color(0xFF111927)],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.34),
          size: 64,
        ),
      ),
    );
  }
}
