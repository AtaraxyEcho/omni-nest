import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/core/widgets/app_empty_state.dart';
import 'package:omninest/core/widgets/app_loading.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/core/errors/error_message.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/domain/photo_face_cluster.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_grid_tile.dart';

enum _PhotoAiAction { reanalyzeLibrary, reclusterFaces }

/// 人脸聚类页面 — 展示按人物分组的照片
class PhotoFacesPage extends ConsumerStatefulWidget {
  const PhotoFacesPage({super.key});

  @override
  ConsumerState<PhotoFacesPage> createState() => _PhotoFacesPageState();
}

class _PhotoFacesPageState extends ConsumerState<PhotoFacesPage> {
  bool _isSubmittingAiTask = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(photoCenterControllerProvider.notifier).loadFaceClusters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(photoCenterControllerProvider);
    return state.when(
      data:
          (data) => _FacesContent(
            clusters: data.faceClusters,
            isLoading: data.isLoadingFaceClusters,
            errorMessage: data.faceClusterError,
            onRetry:
                () =>
                    ref
                        .read(photoCenterControllerProvider.notifier)
                        .loadFaceClusters(),
            isSubmittingAiTask: _isSubmittingAiTask,
            onAiAction: (action) => _submitAiTask(context, action),
            onNameCluster: (id, name) => _nameCluster(context, id, name),
            onViewCluster: (id) => _viewCluster(context, id),
          ),
      loading: () => AppLoading.grid(),
      error:
          (error, _) => Center(
            child: Text(
              AppLocalizations.of(context).photosLoadFailed(error.toString()),
              style: TextStyle(color: context.photosColors.onSurfaceVariant),
            ),
          ),
    );
  }

  Future<void> _submitAiTask(
    BuildContext context,
    _PhotoAiAction action,
  ) async {
    if (_isSubmittingAiTask) return;
    setState(() => _isSubmittingAiTask = true);
    try {
      final controller = ref.read(photoCenterControllerProvider.notifier);
      final taskId = switch (action) {
        _PhotoAiAction.reanalyzeLibrary => await controller.reanalyzeLibrary(),
        _PhotoAiAction.reclusterFaces => await controller.reclusterFaces(),
      };
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).photosAiTaskSubmitted(taskId),
            ),
          ),
        );
      }
    } on Exception {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context).photosAiTaskSubmitFailed,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmittingAiTask = false);
      }
    }
  }

  Future<void> _nameCluster(
    BuildContext context,
    String clusterId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: context.photosColors.surfaceContainerHigh,
            title: Text(
              AppLocalizations.of(context).photosNamePerson,
              style: TextStyle(color: context.photosColors.onSurface),
            ),
            content: TextField(
              controller: controller,
              style: TextStyle(color: context.photosColors.onSurface),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).photosPersonNameHint,
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppLocalizations.of(context).photosCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: Text(AppLocalizations.of(context).photosConfirm),
              ),
            ],
          ),
    );
    if (name != null && name.isNotEmpty && context.mounted) {
      try {
        await ref
            .read(photoCenterControllerProvider.notifier)
            .nameCluster(clusterId, name);
      } on Exception catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(describeUserFacingError(error).displayMessage),
            ),
          );
        }
      }
    }
  }

  Future<void> _viewCluster(BuildContext context, String clusterId) async {
    List<PhotoItem> photos;
    try {
      photos = await ref
          .read(photoCenterControllerProvider.notifier)
          .getPhotosByCluster(clusterId);
    } on Exception catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(describeUserFacingError(error).displayMessage),
          ),
        );
      }
      return;
    }
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.photosColors.surfaceContainerHigh,
      builder: (ctx) => _ClusterPhotosSheet(photos: photos),
    );
  }
}

class _FacesContent extends StatelessWidget {
  const _FacesContent({
    required this.clusters,
    required this.isLoading,
    required this.errorMessage,
    required this.onRetry,
    required this.isSubmittingAiTask,
    required this.onAiAction,
    required this.onNameCluster,
    required this.onViewCluster,
  });

  final List<PhotoFaceCluster> clusters;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onRetry;
  final bool isSubmittingAiTask;
  final ValueChanged<_PhotoAiAction> onAiAction;
  final void Function(String id, String name) onNameCluster;
  final void Function(String id) onViewCluster;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 顶部工具栏
        Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: context.photosColors.surfaceContainer.withValues(
              alpha: 0.70,
            ),
            border: Border(
              bottom: BorderSide(
                color: context.photosColors.outlineVariant.withValues(
                  alpha: 0.32,
                ),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.people_outline,
                color: context.photosColors.onSurfaceVariant,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).photosTabPeople,
                style: TextStyle(
                  color: context.photosColors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              PopupMenuButton<_PhotoAiAction>(
                enabled: !isSubmittingAiTask,
                tooltip: AppLocalizations.of(context).photosAiActions,
                onSelected: onAiAction,
                icon:
                    isSubmittingAiTask
                        ? SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.photosColors.onSurfaceVariant,
                          ),
                        )
                        : Icon(
                          Icons.auto_awesome_outlined,
                          color: context.photosColors.onSurfaceVariant,
                          size: 20,
                        ),
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: _PhotoAiAction.reanalyzeLibrary,
                        child: Row(
                          children: [
                            const Icon(Icons.model_training_rounded, size: 18),
                            const SizedBox(width: 10),
                            Text(
                              AppLocalizations.of(context).photosAnalyzeLibrary,
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _PhotoAiAction.reclusterFaces,
                        child: Row(
                          children: [
                            const Icon(Icons.hub_outlined, size: 18),
                            const SizedBox(width: 10),
                            Text(AppLocalizations.of(context).photosRecluster),
                          ],
                        ),
                      ),
                    ],
              ),
            ],
          ),
        ),
        // 内容
        Expanded(
          child:
              isLoading
                  ? AppLoading.grid()
                  : errorMessage != null
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_outlined,
                          size: 40,
                          color: context.photosColors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).photosLoadFailed(errorMessage!),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: context.photosColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text(AppLocalizations.of(context).coreRetry),
                        ),
                      ],
                    ),
                  )
                  : clusters.isEmpty
                  ? AppEmptyState(
                    message: AppLocalizations.of(context).photosNoFaceData,
                    icon: Icons.face_outlined,
                  )
                  : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.85,
                        ),
                    itemCount: clusters.length,
                    itemBuilder: (context, index) {
                      final cluster = clusters[index];
                      return _FaceClusterCard(
                        cluster: cluster,
                        onTap: () => onViewCluster(cluster.id),
                        onLongPress:
                            () => onNameCluster(cluster.id, cluster.name ?? ''),
                      );
                    },
                  ),
        ),
      ],
    );
  }
}

class _FaceClusterCard extends StatelessWidget {
  const _FaceClusterCard({
    required this.cluster,
    required this.onTap,
    required this.onLongPress,
  });

  final PhotoFaceCluster cluster;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 圆形头像
          CircleAvatar(
            radius: 48,
            backgroundColor: context.photosColors.surfaceContainerLow,
            backgroundImage:
                cluster.coverPhotoUrl != null
                    ? NetworkImage(cluster.coverPhotoUrl!)
                    : null,
            child:
                cluster.coverPhotoUrl == null
                    ? Icon(
                      Icons.person_outline,
                      color: context.photosColors.onSurfaceVariant,
                      size: 40,
                    )
                    : null,
          ),
          SizedBox(height: 8),
          // 名称
          Text(
            cluster.name ?? AppLocalizations.of(context).photosUnnamed,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.photosColors.onSurface,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          // 照片数量
          Text(
            AppLocalizations.of(context).photosFaceCount(cluster.faceCount),
            style: TextStyle(
              color: context.photosColors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClusterPhotosSheet extends StatelessWidget {
  const _ClusterPhotosSheet({required this.photos});

  final List<PhotoItem> photos;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Column(
          children: [
            // 拖拽手柄
            Container(
              margin: EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.photosColors.outlineVariant.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                AppLocalizations.of(context).photosPhotoCount(photos.length),
                style: TextStyle(
                  color: context.photosColors.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child:
                  photos.isEmpty
                      ? Center(
                        child: Text(
                          AppLocalizations.of(context).photosPersonNoPhotos,
                          style: TextStyle(
                            color: context.photosColors.onSurfaceVariant,
                          ),
                        ),
                      )
                      : GridView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1,
                            ),
                        itemCount: photos.length,
                        itemBuilder: (ctx, index) {
                          final photo = photos[index];
                          return PhotoGridTile(
                            key: ValueKey(photo.id),
                            photo: photo,
                            onTap: () {
                              Navigator.pop(ctx);
                              context.push('/photos/${photo.id}');
                            },
                          );
                        },
                      ),
            ),
          ],
        );
      },
    );
  }
}
