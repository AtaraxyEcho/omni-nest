class ReaderReadingStats {
  const ReaderReadingStats({
    required this.totalMinutesToday,
    required this.totalMinutesThisWeek,
    required this.currentStreak,
    required this.totalBooksRead,
  });

  factory ReaderReadingStats.fromJson(Map<String, dynamic> json) {
    return ReaderReadingStats(
      totalMinutesToday: _asInt(json['totalMinutesToday']),
      totalMinutesThisWeek: _asInt(json['totalMinutesThisWeek']),
      currentStreak: _asInt(json['currentStreak']),
      totalBooksRead: _asInt(json['totalBooksRead']),
    );
  }

  factory ReaderReadingStats.empty() => const ReaderReadingStats(
    totalMinutesToday: 0,
    totalMinutesThisWeek: 0,
    currentStreak: 0,
    totalBooksRead: 0,
  );

  final int totalMinutesToday;
  final int totalMinutesThisWeek;
  final int currentStreak;
  final int totalBooksRead;
}

int _asInt(dynamic value) => switch (value) {
  int() => value,
  num() => value.toInt(),
  _ => int.tryParse(value?.toString() ?? '') ?? 0,
};
