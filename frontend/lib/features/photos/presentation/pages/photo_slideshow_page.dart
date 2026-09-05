import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/core/theme/motion_token.dart';
import 'package:omninest/core/window/window_chrome_controller.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/presentation/widgets/slideshow_controls.dart';

/// 全屏幻灯片页面
class PhotoSlideshowPage extends ConsumerStatefulWidget {
  const PhotoSlideshowPage({
    required this.photos,
    this.initialIndex = 0,
    super.key,
  });

  final List<PhotoItem> photos;
  final int initialIndex;

  @override
  ConsumerState<PhotoSlideshowPage> createState() => _PhotoSlideshowPageState();
}

class _PhotoSlideshowPageState extends ConsumerState<PhotoSlideshowPage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _isPlaying = true;
  int _speedSeconds = 5;
  Timer? _autoAdvanceTimer;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  WindowChromeLease? _windowChromeLease;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _startAutoAdvance();
    _scheduleHideControls();
    // 沉浸租约会同步修改 Provider 状态，延迟到首帧后获取，避免构建期报错。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _windowChromeLease = ref
          .read(windowChromeControllerProvider.notifier)
          .acquireImmersive(owner: 'photos.slideshow');
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _hideControlsTimer?.cancel();
    _pageController.dispose();
    _windowChromeLease?.release();
    super.dispose();
  }

  void _startAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    if (!_isPlaying || widget.photos.length <= 1) return;
    _autoAdvanceTimer = Timer.periodic(
      Duration(seconds: _speedSeconds),
      (_) => _next(),
    );
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _next() {
    if (_currentIndex < widget.photos.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      // 循环回到第一张
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previous() {
    if (_currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    if (_isPlaying) {
      _startAutoAdvance();
    } else {
      _autoAdvanceTimer?.cancel();
    }
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) {
      _scheduleHideControls();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.photosColors.slideshowBg,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // 照片页面
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
                if (_isPlaying) _startAutoAdvance();
              },
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                return AnimatedSwitcher(
                  duration: MotionToken.resolve(context, MotionToken.normal),
                  child: Center(
                    key: ValueKey(photo.id),
                    child:
                        photo.hasCover
                            ? InteractiveViewer(
                              minScale: 0.5,
                              maxScale: 5,
                              child: CachedNetworkImage(
                                imageUrl: photo.coverUrl!,
                                fit: BoxFit.contain,
                                placeholder:
                                    (context, url) => Center(
                                      child: CircularProgressIndicator(
                                        color:
                                            context
                                                .photosColors
                                                .primaryContainer,
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => Icon(
                                      Icons.broken_image_outlined,
                                      color:
                                          context.photosColors.slideshowMuted,
                                      size: 64,
                                    ),
                              ),
                            )
                            : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.photo_outlined,
                                  color: context.photosColors.slideshowMuted,
                                  size: 64,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  photo.title,
                                  style: TextStyle(
                                    color: context.photosColors.slideshowMuted,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                  ),
                );
              },
            ),
            // 控制覆盖层
            if (_showControls)
              SlideshowControls(
                isPlaying: _isPlaying,
                currentIndex: _currentIndex,
                totalCount: widget.photos.length,
                speedSeconds: _speedSeconds,
                onPlayPause: _togglePlay,
                onPrevious: _previous,
                onNext: _next,
                onSpeedChanged: (seconds) {
                  setState(() => _speedSeconds = seconds);
                  if (_isPlaying) _startAutoAdvance();
                },
                onClose: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }
}
