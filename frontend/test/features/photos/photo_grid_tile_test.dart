import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/app/theme/app_theme_palette.dart';
import 'package:omninest/features/photos/domain/photo.dart';
import 'package:omninest/features/photos/presentation/widgets/photo_grid_tile.dart';

void main() {
  testWidgets('照片标题和分辨率在分数像素窄卡片内不溢出', (tester) async {
    final photo = PhotoItem(
      id: 'photo-1',
      fileNodeId: 'file-1',
      title: '一个很长的移动端照片文件名称',
      format: 'JPEG',
      fileSize: 1024,
      metadataStatus: 'READY',
      favorite: false,
      createdAt: DateTime(2026),
      width: 12000,
      height: 9000,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniNestTheme.light(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 96.519,
              height: 96,
              child: PhotoGridTile(photo: photo, onTap: () {}),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(photo.title), findsOneWidget);
    expect(find.text(photo.resolutionDisplay!), findsOneWidget);
  });

  testWidgets('缩略图切换不使用淡入动画并保留稳定照片 key', (tester) async {
    final photo = PhotoItem(
      id: 'photo-1',
      fileNodeId: 'file-1',
      title: 'photo.jpg',
      format: 'jpg',
      fileSize: 1,
      metadataStatus: 'READY',
      favorite: false,
      createdAt: DateTime(2026),
      coverUrl: 'https://example.test/photo.jpg',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniNestTheme.from(AppThemePalette.dark),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: SizedBox(
          width: 240,
          height: 240,
          child: PhotoGridTile(
            key: ValueKey(photo.id),
            photo: photo,
            onTap: () {},
          ),
        ),
      ),
    );

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.fadeInDuration, Duration.zero);
    expect(image.fadeOutDuration, Duration.zero);
    expect(find.byKey(const ValueKey('photo-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
