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
final readerCachedImageProvider = FutureProvider.autoDispose
    .family<Uint8List?, ({String itemId, String imagePath})>((ref, request) {
      return ReaderImageCache.loadImage(
        itemId: request.itemId,
        imagePath: request.imagePath,
      );
    });
