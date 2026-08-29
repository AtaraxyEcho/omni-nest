class ReaderNote {
  const ReaderNote({
    required this.id,
    required this.readerItemId,
    required this.content,
    required this.createdAt,
    this.charOffset,
    this.title,
  });

  factory ReaderNote.fromJson(Map<String, dynamic> json) {
    return ReaderNote(
      id: json['id']?.toString() ?? '',
      readerItemId: json['readerItemId']?.toString() ?? '',
      charOffset: _nullableInt(json['charOffset']),
      title: json['title']?.toString(),
      content: json['content']?.toString() ?? '',
      createdAt: _parseDateTime(json['createdAt']),
    );
  }

  final String id;
  final String readerItemId;
  final int? charOffset;
  final String? title;
  final String content;
  final DateTime? createdAt;
}

int _asInt(dynamic value) => switch (value) {
  int() => value,
  num() => value.toInt(),
  _ => int.tryParse(value?.toString() ?? '') ?? 0,
};

int? _nullableInt(dynamic value) {
  if (value == null || value.toString().isEmpty) return null;
  return _asInt(value);
}

DateTime? _parseDateTime(dynamic value) {
  if (value == null || value.toString().isEmpty) return null;
  return DateTime.tryParse(value.toString().replaceFirst(' ', 'T'))?.toLocal();
}
