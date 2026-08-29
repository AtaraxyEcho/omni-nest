import 'package:omninest/core/network/api_client.dart';

/// 文件上传客户端。当前上传逻辑直接通过 [FileApi] 的预签名 URL 完成，
/// 此类保留作为上传相关工具方法的扩展点。
class UploadClient {
  const UploadClient(this.apiClient);

  final ApiClient apiClient;
}
