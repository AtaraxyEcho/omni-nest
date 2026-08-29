import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/features/files/application/file_browser_controller.dart';
import 'package:omninest/features/files/domain/file_manager_models.dart';

final shareLinkControllerProvider =
    AsyncNotifierProvider.autoDispose<ShareLinkController, FileShareLink?>(
      ShareLinkController.new,
    );

/// 我的分享链接列表状态。
final myShareLinksProvider = AsyncNotifierProvider.autoDispose<
  MyShareLinksNotifier,
  List<FileShareLink>
>(MyShareLinksNotifier.new);

class ShareLinkController extends AsyncNotifier<FileShareLink?> {
  @override
  FileShareLink? build() => null;

  /// 创建分享链接并存储到 state。
  Future<FileShareLink> createShareLink({
    required String resourceId,
    required String resourceType,
    String? password,
    bool generatePassword = false,
    DateTime? expiresAt,
    int? maxAccessCount,
  }) async {
    state = const AsyncLoading();
    final repository = ref.read(fileRepositoryProvider);
    final link = await repository.createShareLink(
      resourceId: resourceId,
      resourceType: resourceType,
      password: password,
      generatePassword: generatePassword,
      expiresAt: expiresAt,
      maxAccessCount: maxAccessCount,
    );
    state = AsyncData(link);
    ref.invalidate(fileBrowserControllerProvider);
    ref.invalidate(myShareLinksProvider);
    return link;
  }

  /// 撤销分享链接。
  Future<void> revokeShare(String shareId) async {
    final repository = ref.read(fileRepositoryProvider);
    await repository.revokeShare(shareId);
    state = const AsyncData(null);
    ref.invalidate(fileBrowserControllerProvider);
    ref.invalidate(myShareLinksProvider);
  }

  /// 重置状态（弹窗关闭时调用）。
  void reset() {
    state = const AsyncData(null);
  }
}

class MyShareLinksNotifier extends AsyncNotifier<List<FileShareLink>> {
  @override
  List<FileShareLink> build() => [];

  /// 加载我的分享链接列表。
  Future<void> load() async {
    state = const AsyncLoading();
    final repository = ref.read(fileRepositoryProvider);
    final links = await repository.listMyShares();
    state = AsyncData(links);
  }

  /// 撤销分享链接并刷新列表。
  Future<void> revokeShare(String shareId) async {
    final repository = ref.read(fileRepositoryProvider);
    await repository.revokeShare(shareId);
    ref.invalidate(fileBrowserControllerProvider);
    await load();
  }
}
