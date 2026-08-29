import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/features/reader/domain/reader_models.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_content_annotations.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_content_models.dart';

void main() {
  test('批注投影按边界切分文本并保留行内样式', () {
    final blocks = [
      ParagraphBlock(
        lines: const [
          LineData(
            spans: [ReaderInlineSpan(text: 'Hello world', isBold: true)],
          ),
        ],
      ),
    ];
    final annotations = [
      const ReaderAnnotation(
        id: 'annotation-1',
        readerItemId: 'item-1',
        startOffset: 0,
        endOffset: 5,
        color: '#FFEB3B',
        createdAt: null,
      ),
    ];

    final result = ReaderContentAnnotationProjector.apply(blocks, annotations);
    final paragraph = result.single as ParagraphBlock;
    final spans = paragraph.lines.single.spans;

    expect(spans.map((span) => span.text), ['Hello', ' world']);
    expect(spans.first.backgroundColor, isNotNull);
    expect(spans.first.isBold, isTrue);
    expect(spans.last.backgroundColor, isNull);
  });

  test('没有批注时复用原内容块列表', () {
    final blocks = <ContentBlock>[
      ParagraphBlock(
        lines: const [
          LineData(spans: [ReaderInlineSpan(text: 'Text')]),
        ],
      ),
    ];

    final result = ReaderContentAnnotationProjector.apply(blocks, const []);

    expect(identical(result, blocks), isTrue);
  });
}
