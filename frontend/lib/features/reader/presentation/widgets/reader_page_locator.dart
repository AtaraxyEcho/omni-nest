import 'package:omninest/features/reader/presentation/widgets/reader_content_loader.dart';

/// 阅读器页码定位协调器。
///
/// 同一时间只保留最后一次定位请求，窗口变化、章节切换和搜索跳转不会互相覆盖。
class ReaderPageLocator {
  int _generation = 0;
  bool _isLocating = false;

  /// 当前是否正在定位页码。
  bool get isLocating => _isLocating;

  /// 根据字符偏移异步定位页码。
  Future<int?> locate(PageNavigator navigator, int charOffset) async {
    final generation = ++_generation;
    _isLocating = true;
    final page = await navigator.findPageByCharOffset(
      charOffset,
      isCancelled: () => generation != _generation,
    );
    if (generation != _generation) {
      return null;
    }
    _isLocating = false;
    return page;
  }

  /// 取消当前定位请求。
  void cancel() {
    _generation++;
    _isLocating = false;
  }
}
