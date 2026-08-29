import 'package:cached_network_image/cached_network_image.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_shell.dart';

class MediaGallerySection extends ConsumerWidget {
  const MediaGallerySection({required this.itemId, this.width, super.key});

  final String itemId;
  final double? width;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetsAsync = ref.watch(movieItemAssetsProvider(itemId));
    return assetsAsync.when(
      data: (assets) {
        final screenshots =
            assets.where((a) => a.assetType == 'SCREENSHOT').toList();
        final trailers = assets.where((a) => a.assetType == 'TRAILER').toList();
        if (screenshots.isEmpty && trailers.isEmpty) {
          return SizedBox.shrink();
        }
        final w = width ?? MediaQuery.sizeOf(context).width;
        final titleSize = ms(w, 17);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).videoMediaGallery,
              style: TextStyle(
                color: context.videoColors.onSurface,
                fontSize: titleSize,
                height: 24 / 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (screenshots.isNotEmpty) ...[
              const SizedBox(height: 14),
              SizedBox(
                height: 200,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                    },
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: screenshots.length,
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder:
                        (context, index) => GestureDetector(
                          onTap:
                              () => _openLightbox(context, screenshots, index),
                          child: _ScreenshotCard(
                            asset: screenshots[index],
                            cardWidth:
                                w >= 1920
                                    ? 400.0
                                    : w >= 1280
                                    ? 360.0
                                    : w >= 720
                                    ? 300.0
                                    : 240.0,
                          ),
                        ),
                  ),
                ),
              ),
            ],
            if (trailers.isNotEmpty) ...[
              SizedBox(height: 18),
              Text(
                AppLocalizations.of(context).videoTrailer,
                style: TextStyle(
                  color: context.videoColors.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              for (final trailer in trailers) _TrailerRow(asset: trailer),
            ],
          ],
        );
      },
      error: (_, _) => const SizedBox.shrink(),
      loading: () => const SizedBox.shrink(),
    );
  }

  void _openLightbox(
    BuildContext context,
    List<MovieContentAsset> screenshots,
    int initialIndex,
  ) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _LightboxViewer(
          screenshots: screenshots,
          initialIndex: initialIndex,
        );
      },
    );
  }
}

class _LightboxViewer extends StatefulWidget {
  const _LightboxViewer({
    required this.screenshots,
    required this.initialIndex,
  });

  final List<MovieContentAsset> screenshots;
  final int initialIndex;

  @override
  State<_LightboxViewer> createState() => _LightboxViewerState();
}

class _LightboxViewerState extends State<_LightboxViewer> {
  late final PageController _pageController;
  late final FocusNode _focusNode;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _focusNode = FocusNode()..requestFocus();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft && _currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight &&
        _currentIndex < widget.screenshots.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
      );
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      autofocus: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.screenshots.length,
              onPageChanged: (index) => setState(() => _currentIndex = index),
              itemBuilder: (context, index) {
                final url = widget.screenshots[index].url;
                if (url == null || url.isEmpty) {
                  return const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white38,
                      size: 48,
                    ),
                  );
                }
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.contain,
                      memCacheWidth: 1920,
                      errorWidget:
                          (_, _, _) => const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white38,
                              size: 48,
                            ),
                          ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: IconButton(
                tooltip: AppLocalizations.of(context).coreClose,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black45,
                  shape: const CircleBorder(),
                ),
              ),
            ),
            if (widget.screenshots.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.screenshots.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScreenshotCard extends StatelessWidget {
  const _ScreenshotCard({required this.asset, required this.cardWidth});

  final MovieContentAsset asset;
  final double cardWidth;

  @override
  Widget build(BuildContext context) {
    final url = asset.url;
    return Container(
      width: cardWidth,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: context.videoColors.surfaceContainerHighest,
      ),
      child:
          url != null && url.isNotEmpty
              ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                memCacheWidth: 400,
                errorWidget:
                    (_, _, _) =>
                        const _AssetPlaceholder(icon: Icons.image_rounded),
              )
              : const _AssetPlaceholder(icon: Icons.image_rounded),
    );
  }
}

class _TrailerRow extends StatelessWidget {
  const _TrailerRow({required this.asset});

  final MovieContentAsset asset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            color: context.videoColors.primary,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              asset.language ?? AppLocalizations.of(context).videoTrailer,
              style: TextStyle(
                color: context.videoColors.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            asset.provider ?? '',
            style: TextStyle(
              color: context.videoColors.onSurfaceVariant.withValues(
                alpha: 0.62,
              ),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetPlaceholder extends StatelessWidget {
  const _AssetPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        icon,
        color: context.videoColors.onSurfaceVariant.withValues(alpha: 0.42),
      ),
    );
  }
}
