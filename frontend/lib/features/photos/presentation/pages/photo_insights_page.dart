import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_relation_view.dart';

/// 关联视图页：展示时间、地点与相册之间的共现关系。
class PhotoInsightsPage extends ConsumerWidget {
  const PhotoInsightsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.photosInsightsTitle)),
      body: const PhotoRelationView(),
    );
  }
}
