import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/app_theme.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_bookmark_list.dart';

void main() {
  const item = ReaderItem(
    id: 'book-1',
    title: 'Architecture Notes',
    itemType: 'EPUB',
    updatedAt: null,
  );
  final bookmark = ReaderBookmark(
    id: 'bookmark-1',
    readerItemId: item.id,
    charOffset: 120,
    progressPercent: 0.42,
    chapterTitle: 'Chapter 3',
    note: 'Review this section',
    createdAt: DateTime.utc(2026, 7, 25),
  );

  testWidgets('展示书签信息并打开关联条目', (tester) async {
    ReaderItem? openedItem;

    await tester.pumpWidget(
      _TestApp(
        child: ReaderBookmarkList(
          bookmarks: [bookmark],
          items: const [item],
          onOpenItem: (value) => openedItem = value,
        ),
      ),
    );

    expect(find.text(item.title), findsOneWidget);
    expect(find.text('Chapter 3'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsOneWidget);

    await tester.tap(find.text(item.title));
    expect(openedItem, same(item));
  });

  testWidgets('书库条目更新后刷新书签映射', (tester) async {
    await tester.pumpWidget(
      _TestApp(
        child: ReaderBookmarkList(
          bookmarks: [bookmark],
          items: const [],
          onOpenItem: (_) {},
        ),
      ),
    );

    expect(find.text('Unknown book'), findsOneWidget);

    await tester.pumpWidget(
      _TestApp(
        child: ReaderBookmarkList(
          bookmarks: [bookmark],
          items: const [item],
          onOpenItem: (_) {},
        ),
      ),
    );

    expect(find.text(item.title), findsOneWidget);
    expect(find.text('Unknown book'), findsNothing);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: OmniNestTheme.dark(),
      home: Scaffold(body: child),
    );
  }
}
