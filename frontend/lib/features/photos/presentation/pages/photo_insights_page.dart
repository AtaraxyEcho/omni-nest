import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_graph_view.dart';

/// 关联视图页：由图库顶栏进入，展示时间、地点与相册之间的共现关系。
/// 阶段三将把内部实现替换为确定性关联面板。
class PhotoInsightsPage extends ConsumerWidget {
  const PhotoInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(photoCenterControllerProvider);
    final colors = context.photosColors;
    return Scaffold(
      backgroundColor: colors.surface,
      body: stateAsync.when(
        data:
            (state) => PhotoGraphView(
              state: state,
              onOpenPhoto: (photo) => context.push('/photos/${photo.id}'),
              onOpenAlbum:
                  (album) => context.push('/photos/albums/${album.id}'),
            ),
        error:
            (error, stackTrace) => Center(
              child: Text(error.toString(), textAlign: TextAlign.center),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
