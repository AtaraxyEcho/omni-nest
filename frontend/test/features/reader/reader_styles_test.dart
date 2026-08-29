import 'package:flutter_test/flutter_test.dart';
import 'package:omninest/features/reader/presentation/widgets/reader_styles.dart';

void main() {
  group('readerGridColumnCount', () {
    test('紧凑手机宽度使用两列书架', () {
      expect(readerGridColumnCount(320), 2);
      expect(readerGridColumnCount(559), 2);
    });

    test('大屏宽度逐级增加书架列数', () {
      expect(readerGridColumnCount(560), 3);
      expect(readerGridColumnCount(1180), 4);
      expect(readerGridColumnCount(1800), 6);
      expect(readerGridColumnCount(2400), 8);
      expect(readerGridColumnCount(3840), 12);
    });
  });
}
