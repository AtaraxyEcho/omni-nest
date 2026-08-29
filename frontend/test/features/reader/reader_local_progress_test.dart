import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/features/reader/application/reader_local_progress.dart';

void main() {
  test('阅读进度门面将操作委托给注入的存储端口', () async {
    final store = _FakeReaderLocalProgressStore();
    ReaderLocalProgress.init(store);

    await ReaderLocalProgress.save(
      itemId: 'book-1',
      chapterProgress: 0.42,
      mode: 'page',
      chapterId: 'chapter-2',
      charOffset: 128,
      pageId: 'page-3',
      pageIndex: 2,
    );

    expect(store.savedItemId, 'book-1');
    expect(store.savedChapterId, 'chapter-2');
    expect(store.savedCharOffset, 128);
    expect(await ReaderLocalProgress.load('book-1', 'chapter-2'), {
      'kind': 'chapter',
    });
    expect(await ReaderLocalProgress.loadLatest('book-1'), {'kind': 'latest'});

    await ReaderLocalProgress.clear('book-1');
    expect(store.clearedItemId, 'book-1');
  });
}

class _FakeReaderLocalProgressStore implements ReaderLocalProgressStore {
  String? savedItemId;
  String? savedChapterId;
  int? savedCharOffset;
  String? clearedItemId;

  @override
  Future<void> save({
    required String itemId,
    required double chapterProgress,
    required String mode,
    String? chapterId,
    int charOffset = 0,
    String? pageId,
    int? pageIndex,
    String? pageFingerprint,
    String? sourceId,
    int? sourcePageIndex,
    String? catalogKey,
    int? manifestVersion,
    double? intraPageOffset,
  }) async {
    savedItemId = itemId;
    savedChapterId = chapterId;
    savedCharOffset = charOffset;
  }

  @override
  Future<Map<String, dynamic>?> load(String itemId, String chapterId) async {
    return {'kind': 'chapter'};
  }

  @override
  Future<Map<String, dynamic>?> loadLatest(String itemId) async {
    return {'kind': 'latest'};
  }

  @override
  Future<void> clear(String itemId) async {
    clearedItemId = itemId;
  }
}
