import 'package:cached_network_image/cached_network_image.dart';
import 'package:omninest/app/theme/feature/files_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/features/files/application/file_download_url_provider.dart';
import 'package:omninest/features/files/domain/file_node.dart';

/// 文件缩略图组件。
/// 图片文件显示实际缩略图，其他文件显示类型图标。
class FileThumbnail extends ConsumerWidget {
  const FileThumbnail({required this.file, this.size = 40, super.key});

  final FileNode file;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (file.isFolder || !_isImageMimeType(file.mimeType)) {
      return _FileIcon(file: file, size: size);
    }

    final urlAsync = ref.watch(fileDownloadUrlProvider(file.id));
    return urlAsync.when(
      data: (url) {
        if (url == null || url.isEmpty) {
          return _FileIcon(file: file, size: size);
        }
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: url,
            width: size,
            height: size,
            fit: BoxFit.cover,
            memCacheWidth: (size * 2).toInt(),
            placeholder: (context, url) => _FileIcon(file: file, size: size),
            errorWidget:
                (context, url, error) => _FileIcon(file: file, size: size),
          ),
        );
      },
      loading: () => _FileIcon(file: file, size: size),
      error: (e, st) => _FileIcon(file: file, size: size),
    );
  }

  static bool _isImageMimeType(String? mimeType) {
    if (mimeType == null) return false;
    return mimeType.startsWith('image/');
  }
}

/// 通用文件类型图标。
class _FileIcon extends StatelessWidget {
  const _FileIcon({required this.file, required this.size});

  final FileNode file;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent =
        file.isFolder
            ? context.filesColors.tertiary
            : context.filesColors.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size > 48 ? 14 : 12),
      ),
      child: Icon(
        file.isFolder ? Icons.folder_rounded : _fileTypeIcon(file.mimeType),
        size: size * 0.5,
        color: accent,
      ),
    );
  }

  static IconData _fileTypeIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file_outlined;
    if (mimeType.startsWith('video/')) return Icons.movie_outlined;
    if (mimeType.startsWith('audio/')) return Icons.audio_file_outlined;
    if (mimeType.startsWith('image/')) return Icons.image_outlined;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf_outlined;
    if (mimeType.startsWith('text/')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }
}
