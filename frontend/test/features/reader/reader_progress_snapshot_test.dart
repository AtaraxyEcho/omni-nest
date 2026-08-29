import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/features/reader/application/reader_progress_snapshot.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';

void main() {
  group('ReaderProgressSnapshot', () {
    test('normalizes server progress percent to chapter progress', () {
      final snapshot = ReaderProgressSnapshot.fromServer(
        ReaderProgress(
          readerItemId: 'item-1',
          charOffset: 100,
          progressPercent: 20,
          readingMode: 'scroll',
          updatedAt: DateTime(2026),
        ),
      );

      expect(snapshot, isNotNull);
      // V2: server doesn't store chapterId, determined client-side from charOffset
      expect(snapshot.chapterId, '');
      expect(snapshot.charOffset, 100);
      expect(snapshot.progress, 0.2);
      expect(snapshot.mode, 'scroll');
      expect(snapshot.updatedAt, DateTime(2026));
    });

    test('keeps local progress when it is newer than server progress', () {
      final local = ReaderProgressSnapshot.fromLocal({
        'chapterId': 'chapter-1',
        'chapterProgress': 0.35,
        'charOffset': 120,
        'updatedAt': DateTime(2026, 1, 2).toIso8601String(),
      });
      final server = ReaderProgressSnapshot.fromServer(
        ReaderProgress(
          readerItemId: 'item-1',
          charOffset: 0,
          progressPercent: 10,
          readingMode: 'scroll',
          updatedAt: DateTime(2026, 1),
        ),
      );

      final latest = ReaderProgressSnapshot.latest(local, server);

      expect(latest, same(local));
      expect(latest!.progress, 0.35);
      expect(latest.charOffset, 120);
    });

    test('uses newer server progress when its timestamp is later', () {
      final local = ReaderProgressSnapshot.fromLocal({
        'chapterId': 'chapter-1',
        'charOffset': 120,
        'updatedAt': DateTime(2026, 1).toIso8601String(),
      });
      final server = ReaderProgressSnapshot.fromServer(
        ReaderProgress(
          readerItemId: 'item-1',
          chapterId: 'chapter-1',
          charOffset: 360,
          progressPercent: 30,
          readingMode: 'page',
          updatedAt: DateTime(2026, 1, 2),
        ),
      );

      final latest = ReaderProgressSnapshot.latest(local, server);

      expect(latest, same(server));
      expect(latest!.charOffset, 360);
      expect(latest.mode, 'page');
    });

    test('resolves continue-reading chapter from progress snapshot', () {
      final chapters = [
        ReaderChapter(id: 'chapter-1', chapterNumber: 1, title: '第一章'),
        ReaderChapter(id: 'chapter-2', chapterNumber: 2, title: '第二章'),
      ];
      final snapshot = ReaderProgressSnapshot(
        chapterId: 'chapter-2',
        progress: 0.2,
      );

      final chapter = ReaderProgressSnapshot.resolveChapter(chapters, snapshot);

      expect(chapter?.id, 'chapter-2');
    });
  });
}
