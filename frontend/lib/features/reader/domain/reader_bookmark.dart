class ReaderBookmark {
  const ReaderBookmark({
    required this.id,
    required this.readerItemId,
    required this.charOffset,
    required this.progressPercent,
    required this.createdAt,
    this.chapterId,
    this.chapterTitle,
    this.note,
  });

  factory ReaderBookmark.fromJson(Map<String, dynamic> json) {
    return ReaderBookmark(
      id: json['id']?.toString() ?? '',
      readerItemId: json['readerItemId']?.toString() ?? '',
      charOffset: _asInt(json['charOffset']),
      progressPercent: _asDouble(json['progressPercent']),
      chapterId: json['chapterId']?.toString(),
      chapterTitle: json['chapterTitle']?.toString(),
      note: json['note']?.toString(),
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  final String id;
  final String readerItemId;
  final int charOffset;
  final double progressPercent;

  /// 章节 ID（可选，旧版兼容字段，新版按全书偏移定位）
  final String? chapterId;

  /// 章节标题（可选，用于书签列表展示）
  final String? chapterTitle;
  final String? note;
  final DateTime? createdAt;
}

int _asInt(dynamic value) => switch (value) {
  int() => value,
  num() => value.toInt(),
  _ => int.tryParse(value?.toString() ?? '') ?? 0,
};

double _asDouble(dynamic value) => switch (value) {
  double() => value,
  num() => value.toDouble(),
  _ => double.tryParse(value?.toString() ?? '') ?? 0.0,
};

DateTime? _parseDateTime(dynamic value) {
  if (value == null || value.toString().isEmpty) return null;
  return DateTime.tryParse(value.toString().replaceFirst(' ', 'T'))?.toLocal();
}
