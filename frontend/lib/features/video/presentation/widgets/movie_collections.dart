import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/video_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/features/video/application/movie_controller.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_common_widgets.dart';
import 'package:omninest/features/video/presentation/widgets/movie_styles.dart';

import 'movie_feedback.dart';

class CollectionsSection extends ConsumerWidget {
  const CollectionsSection({
    required this.totalCount,
    required this.collections,
    super.key,
  });

  final int totalCount;
  final List<MovieCollection> collections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: MovieSectionHeading(
                title: AppLocalizations.of(context).videoSectionCollections,
                subtitle: AppLocalizations.of(context).videoCollectionsSubtitle,
              ),
            ),
            FilledButton.icon(
              onPressed: () => _showCreateCollectionDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
              label: Text(AppLocalizations.of(context).videoNewCollection),
              style: movieFilledButtonStyle(context),
            ),
          ],
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000 ? 3 : 1;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 18,
              mainAxisSpacing: 18,
              childAspectRatio: columns == 3 ? 2.2 : 3.2,
              children: [
                CollectionCard(
                  title: AppLocalizations.of(context).videoAllMedia,
                  count: totalCount,
                ),
                for (final item in collections)
                  CollectionCard(
                    title: item.name,
                    count: item.itemCount,
                    subtitle: item.collectionType,
                    collectionId: item.id,
                    onTap: () => _showCollectionItems(context, ref, item),
                  ),
                if (collections.isEmpty)
                  CollectionCard(
                    title: AppLocalizations.of(context).videoCustomCollection,
                    count: 0,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

Future<void> _showCreateCollectionDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final nameController = TextEditingController();
  final descriptionController = TextEditingController();
  final created = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: context.videoColors.surfaceContainerHigh,
          title: Text(AppLocalizations.of(context).videoNewCollection),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: TextStyle(
                  color: context.videoColors.onSurface,
                  fontSize: 14,
                ),
                decoration: movieInputDecoration(
                  context,
                  AppLocalizations.of(context).videoCollectionName,
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                style: TextStyle(
                  color: context.videoColors.onSurface,
                  fontSize: 14,
                ),
                decoration: movieInputDecoration(
                  context,
                  AppLocalizations.of(context).videoDescription,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(AppLocalizations.of(context).videoCancel),
              ),
            ),
            SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(AppLocalizations.of(context).videoCreate),
              ),
            ),
          ],
        ),
  );
  if (created != true || !context.mounted) {
    nameController.dispose();
    descriptionController.dispose();
    return;
  }
  final name = nameController.text.trim();
  final description = descriptionController.text.trim();
  nameController.dispose();
  descriptionController.dispose();
  if (name.isEmpty) {
    showMovieMessage(
      context,
      AppLocalizations.of(context).videoCollectionNameEmpty,
    );
    return;
  }
  await runMovieAction(
    context,
    () => ref
        .read(movieCenterControllerProvider.notifier)
        .createCollection(
          name: name,
          description: description.isEmpty ? null : description,
        ),
    AppLocalizations.of(context).videoCollectionCreated,
  );
}

Future<void> _showCollectionItems(
  BuildContext context,
  WidgetRef ref,
  MovieCollection collection,
) async {
  final itemsAsync = ref.read(collectionItemsProvider(collection.id));
  await showDialog<void>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          backgroundColor: context.videoColors.surfaceContainerHigh,
          title: Text(collection.name),
          content: SizedBox(
            width: 500,
            height: 400,
            child: itemsAsync.when(
              data:
                  (items) =>
                      items.isEmpty
                          ? Center(
                            child: Text(
                              AppLocalizations.of(context).videoCollectionEmpty,
                            ),
                          )
                          : ListView.builder(
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final item = items[index];
                              return ListTile(
                                title: Text(item.title),
                                subtitle: Text(item.year),
                                trailing: IconButton(
                                  tooltip:
                                      AppLocalizations.of(context).coreDelete,
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () async {
                                    if (!context.mounted) return;
                                    try {
                                      await ref
                                          .read(
                                            movieCenterControllerProvider
                                                .notifier,
                                          )
                                          .removeCollectionItem(
                                            collectionId: collection.id,
                                            videoItemId: item.id,
                                          );
                                    } on Object catch (error) {
                                      if (context.mounted) {
                                        showMovieFeedback(
                                          context,
                                          movieErrorMessage(error),
                                          isError: true,
                                        );
                                      }
                                      return;
                                    }
                                    if (!context.mounted) return;
                                    ref.invalidate(
                                      collectionItemsProvider(collection.id),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (e, _) => Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      ).videoLoadFailedWith(e.toString()),
                    ),
                  ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(AppLocalizations.of(context).videoClose),
            ),
          ],
        ),
  );
}

class CollectionCard extends StatelessWidget {
  const CollectionCard({
    required this.title,
    required this.count,
    this.subtitle,
    this.collectionId,
    this.onTap,
    super.key,
  });

  final String title;
  final int count;
  final String? subtitle;
  final String? collectionId;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: context.videoColors.surfaceContainerHigh.withValues(
            alpha: 0.75,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.videoColors.outlineVariant.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(
              Icons.video_collection_rounded,
              color: context.videoColors.primary,
              size: 28,
            ),
            Spacer(),
            Text(
              title,
              style: TextStyle(
                color: context.videoColors.onSurface,
                fontSize: 18,
                height: 24 / 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6),
            Text(
              subtitle == null ? '$count items' : '$count items · $subtitle',
              style: TextStyle(
                color: context.videoColors.onSurfaceVariant,
                fontSize: 13,
                height: 18 / 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
