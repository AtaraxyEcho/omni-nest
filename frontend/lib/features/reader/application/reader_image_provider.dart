import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/features/reader/application/reader_controller.dart';
import 'package:omninest/features/reader/data/reader_image_cache.dart';
import 'package:omninest/features/reader/reader_debug_log.dart';

/// 阅读封面图片字节。
final coverBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, itemId) async {
      try {
        return await ref.read(readerApiProvider).getCoverImage(itemId);
      } on Exception catch (error) {
        if (kDebugMode) {
          readerDebugLog('CoverImage: download failed for $itemId: $error');
        }
        return null;
      }
    });

/// 阅读正文缓存图片字节。
///
/// [request.bust] 为失败重试计数：占位图点击重试时递增，family 键
/// 随之变化使 provider 重新执行，而不是永远缓存上一次的失败结果。
final readerCachedImageProvider = FutureProvider.autoDispose
    .family<Uint8List?, ({String itemId, String imagePath, int bust})>((
      ref,
      request,
    ) {
      return ReaderImageCache.loadImage(
        itemId: request.itemId,
        imagePath: request.imagePath,
      );
    });
