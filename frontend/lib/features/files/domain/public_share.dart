/// 公开分享访问仓储契约。
abstract interface class PublicShareRepository {
  Future<SharePreviewResult> preview(String token, {String? password});

  Future<ShareAcceptResult> accept(
    String token, {
    String? password,
    String? authToken,
  });
}

/// 公开分享预览结果。
sealed class SharePreviewResult {
  const SharePreviewResult();

  factory SharePreviewResult.success({
    required String fileName,
    String? mimeType,
    required int sizeBytes,
    required String resourceType,
    required bool hasPassword,
  }) = SharePreviewSuccess;

  factory SharePreviewResult.needPassword(String message) =
      SharePreviewNeedPassword;

  factory SharePreviewResult.error(String message) = SharePreviewError;
}

class SharePreviewSuccess extends SharePreviewResult {
  const SharePreviewSuccess({
    required this.fileName,
    this.mimeType,
    required this.sizeBytes,
    required this.resourceType,
    required this.hasPassword,
  });

  final String fileName;
  final String? mimeType;
  final int sizeBytes;
  final String resourceType;
  final bool hasPassword;
}

class SharePreviewNeedPassword extends SharePreviewResult {
  const SharePreviewNeedPassword(this.message);

  final String message;
}

class SharePreviewError extends SharePreviewResult {
  const SharePreviewError(this.message);

  final String message;
}

/// 接受公开分享的结果。
sealed class ShareAcceptResult {
  const ShareAcceptResult();

  factory ShareAcceptResult.success() = ShareAcceptSuccess;

  factory ShareAcceptResult.duplicate(String message) = ShareAcceptDuplicate;

  factory ShareAcceptResult.error(String message) = ShareAcceptError;
}

class ShareAcceptSuccess extends ShareAcceptResult {
  const ShareAcceptSuccess();
}

class ShareAcceptDuplicate extends ShareAcceptResult {
  const ShareAcceptDuplicate(this.message);

  final String message;
}

class ShareAcceptError extends ShareAcceptResult {
  const ShareAcceptError(this.message);

  final String message;
}
