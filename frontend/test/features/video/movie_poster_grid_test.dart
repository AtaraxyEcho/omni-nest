import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_poster_grid.dart';

void main() {
  testWidgets('暗色影片封面不叠加渐变遮罩', (tester) async {
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
        home: const Scaffold(
          body: SizedBox(
            width: 220,
            height: 320,
            child: PosterArt(item: item, hovered: false),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(PosterArt),
        matching: find.byType(IgnorePointer),
      ),
      findsNothing,
    );
  });
}
