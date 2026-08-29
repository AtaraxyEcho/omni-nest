/// 阅读器空间类型枚举
enum ReaderSpaceType {
  personal('PERSONAL'),
  shared('SHARED');

  const ReaderSpaceType(this.value);
  final String value;

  static ReaderSpaceType fromString(String? value) {
    return switch (value?.toUpperCase()) {
      'SHARED' => ReaderSpaceType.shared,
      _ => ReaderSpaceType.personal,
    };
  }
}
