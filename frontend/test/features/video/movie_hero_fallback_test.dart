import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/features/video/domain/movie_models.dart';
import 'package:omninest/features/video/presentation/widgets/movie_hero.dart';
import 'package:omninest/features/video/presentation/widgets/movie_series.dart';

void main() {
  test('movieHeroItems 纳入仅有海报的条目并回退海报图', () {
    final posterOnly = _movie(
      id: 'poster-only',
      posterUrl: 'http://minio/poster.jpg',
    );

    final heroes = movieHeroItems([posterOnly]);

    expect(heroes, hasLength(1));
    expect(heroes.single.heroImageUrl, 'http://minio/poster.jpg');
  });

  test('movieHeroItems 背景图优先于海报图', () {
    final item = _movie(
      id: 'both',
      posterUrl: 'http://minio/poster.jpg',
      backdropUrl: 'http://minio/backdrop.jpg',
    );

    expect(
      movieHeroItems([item]).single.heroImageUrl,
      'http://minio/backdrop.jpg',
    );
  });

  test('seriesHeroItems 纳入仅有海报的剧集并回退海报图', () {
    final backdropSeries = _series(
      id: 'with-backdrop',
      backdropUrl: 'http://minio/backdrop.jpg',
    );
    final posterOnly = _series(
      id: 'poster-only',
      posterUrl: 'http://minio/p.jpg',
    );

    final heroes = seriesHeroItems([backdropSeries, posterOnly]);

    expect(heroes.map((s) => s.id).toSet(), {'with-backdrop', 'poster-only'});
    expect(
      heroes.firstWhere((s) => s.id == 'poster-only').heroImageUrl,
      'http://minio/p.jpg',
    );
  });
}

MovieVideoItem _movie({
  required String id,
  String? posterUrl,
  String? backdropUrl,
}) {
  return MovieVideoItem(
    id: id,
    fileNodeId: 'file-$id',
    mediaType: 'MOVIE',
    title: id,
    metadataStatus: 'MATCHED',
    nfoStatus: 'DISABLED',
    updatedAt: null,
    metadata: const {},
    posterUrl: posterUrl,
    backdropUrl: backdropUrl,
  );
}

MovieSeries _series({
  required String id,
  String? posterUrl,
  String? backdropUrl,
}) {
  return MovieSeries(
    id: id,
    title: id,
    metadataStatus: 'MATCHED',
    metadata: const {},
    posterUrl: posterUrl,
    backdropUrl: backdropUrl,
  );
}
