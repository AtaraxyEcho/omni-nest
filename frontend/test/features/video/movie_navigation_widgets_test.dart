import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_common_widgets.dart';
import 'package:omninest/features/video/presentation/widgets/movie_detail_recommendations.dart';

void main() {
  testWidgets('详情页返回控件具有明确标签并执行回调', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: OmniNestTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: Scaffold(
          body: MovieDetailBackButton(onPressed: () => tapped = true),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('movieDetailBackButton')), findsOneWidget);
    expect(find.text('返回影库'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('movieDetailBackButton')));
    expect(tapped, isTrue);
  });

  testWidgets('推荐封面静止状态不叠加遮罩', (tester) async {
    const item = MovieVideoItem(
      id: 'movie-1',
      fileNodeId: 'file-1',
      mediaType: 'MOVIE',
      title: '影片',
      metadataStatus: 'READY',
      nfoStatus: 'READY',
      updatedAt: null,
      metadata: <String, dynamic>{},
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: OmniNestTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 390,
            height: 300,
            child: MovieRecommendations(recommended: <MovieVideoItem>[item]),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(MovieRecommendations),
        matching: find.byType(Positioned),
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
