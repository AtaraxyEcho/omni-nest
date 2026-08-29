import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:omninest/features/backdrop/domain/app_backdrop.dart';
import 'package:path/path.dart' as p;

/// 桌面端应用背景扫描器。
class AppBackdropScanner {
  static const _imageExts = <String>{'.jpg', '.jpeg', '.png', '.webp'};
  static const _gifExts = <String>{'.gif'};
  static const _videoExts = <String>{'.mp4', '.webm', '.mov', '.m4v'};
  static const _maxScanDepth = 4;
  static const _maxScanFiles = 1200;

  /// 从本机文件路径构建背景素材。
  Future<List<AppBackdropAsset>> fromFiles(
    List<String> paths, {
    AppBackdropSourceType sourceType = AppBackdropSourceType.file,
    String? sourceDirectory,
  }) async {
    final result = <AppBackdropAsset>[];
    final seen = <String>{};
    final previewCache = <String, String?>{};
    for (final path in paths) {
      final normalized = p.normalize(path);
      if (!seen.add(normalized)) {
        continue;
      }
      final asset = await _fromFile(
        File(normalized),
        sourceType: sourceType,
        sourceDirectory: sourceDirectory,
        previewCache: previewCache,
      );
      if (asset != null) {
        result.add(asset);
      }
    }
    return result;
  }

  /// 扫描本机目录。
  Future<List<AppBackdropAsset>> scanDirectory(String directoryPath) async {
    final directory = Directory(directoryPath);
    if (!await directory.exists()) {
      return const <AppBackdropAsset>[];
    }
    final files = <String>[];
    await _collectFiles(directory, 0, files);
    return fromFiles(
      files,
      sourceType: AppBackdropSourceType.directory,
      sourceDirectory: p.normalize(directoryPath),
    );
  }

  /// 检测文件缺失状态。
  Future<Map<String, bool>> detectMissing(
    List<AppBackdropAsset> backdrops,
  ) async {
    final result = <String, bool>{};
    for (final backdrop in backdrops) {
      result[backdrop.id] = !await File(backdrop.path).exists();
    }
    return result;
  }

  Future<void> _collectFiles(
    Directory directory,
    int depth,
    List<String> files,
  ) async {
    if (depth > _maxScanDepth || files.length >= _maxScanFiles) {
      return;
    }
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (files.length >= _maxScanFiles) {
          return;
        }
        if (entity is File &&
            _isSupportedPath(entity.path) &&
            !_isPreviewPath(entity.path)) {
          files.add(entity.path);
        } else if (entity is Directory) {
          final name = p.basename(entity.path);
          if (_shouldSkipDirectory(name)) {
            continue;
          }
          await _collectFiles(entity, depth + 1, files);
        }
      }
    } on Object {
      return;
    }
  }

  Future<AppBackdropAsset?> _fromFile(
    File file, {
    required AppBackdropSourceType sourceType,
    String? sourceDirectory,
    required Map<String, String?> previewCache,
  }) async {
    try {
      if (!await file.exists() ||
          !_isSupportedPath(file.path) ||
          _isPreviewPath(file.path)) {
        return null;
      }
      final stat = await file.stat();
      final normalized = p.normalize(file.path);
      final now = DateTime.now();
      return AppBackdropAsset(
        id: _buildId(normalized),
        path: normalized,
        title: _titleFromPath(normalized),
        mediaType: _mediaType(normalized),
        sourceType: sourceType,
        sourceDirectory: sourceDirectory,
        fileSize: stat.size,
        modifiedAt: stat.modified,
        thumbnailPath: await _findPreviewPath(normalized, previewCache),
        createdAt: now,
        updatedAt: now,
      );
    } on Object {
      return null;
    }
  }

  bool _isSupportedPath(String path) {
    final ext = p.extension(path).toLowerCase();
    return _imageExts.contains(ext) ||
        _gifExts.contains(ext) ||
        _videoExts.contains(ext);
  }

  bool _isRenderablePath(String path) {
    final ext = p.extension(path).toLowerCase();
    return _imageExts.contains(ext) ||
        _gifExts.contains(ext) ||
        _videoExts.contains(ext);
  }

  bool _isPreviewPath(String path) {
    return p.basenameWithoutExtension(path).toLowerCase() == 'preview';
  }

  Future<String?> _findPreviewPath(
    String mediaPath,
    Map<String, String?> previewCache,
  ) async {
    final directory = Directory(p.dirname(mediaPath));
    final directoryPath = p.normalize(directory.path);
    if (previewCache.containsKey(directoryPath)) {
      return previewCache[directoryPath];
    }
    if (!await directory.exists()) {
      previewCache[directoryPath] = null;
      return null;
    }
    final candidates = <String, String>{};
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final normalized = p.normalize(entity.path);
        if (normalized == mediaPath ||
            !_isPreviewPath(normalized) ||
            !_isRenderablePath(normalized)) {
          continue;
        }
        candidates[p.extension(normalized).toLowerCase()] = normalized;
      }
    } on Object {
      previewCache[directoryPath] = null;
      return null;
    }
    for (final ext in <String>['.gif', '.webp', '.png', '.jpg', '.jpeg']) {
      final candidate = candidates[ext];
      if (candidate != null) {
        previewCache[directoryPath] = candidate;
        return candidate;
      }
    }
    final fallback = candidates.values.isEmpty ? null : candidates.values.first;
    previewCache[directoryPath] = fallback;
    return fallback;
  }

  bool _shouldSkipDirectory(String name) {
    final normalized = name.toLowerCase();
    return normalized.startsWith('.') ||
        normalized == 'node_modules' ||
        normalized == 'cache' ||
        normalized == 'tmp' ||
        normalized == 'temp';
  }

  AppBackdropMediaType _mediaType(String path) {
    final ext = p.extension(path).toLowerCase();
    if (_videoExts.contains(ext)) {
      return AppBackdropMediaType.video;
    }
    if (_gifExts.contains(ext)) {
      return AppBackdropMediaType.gif;
    }
    return AppBackdropMediaType.image;
  }

  String _titleFromPath(String path) {
    return p.basenameWithoutExtension(path).replaceAll(RegExp(r'[_\-]+'), ' ');
  }

  String _buildId(String normalizedPath) {
    return sha1.convert(normalizedPath.toLowerCase().codeUnits).toString();
  }
}
