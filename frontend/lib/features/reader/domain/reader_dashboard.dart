import 'package:omninest/features/reader/domain/reader_item.dart';

class ReaderDashboard {
  const ReaderDashboard({
    required this.overview,
    required this.continueReading,
    required this.recentItems,
  });

  factory ReaderDashboard.empty() => ReaderDashboard(
    overview: ReaderOverview.empty(),
    continueReading: const [],
    recentItems: const [],
  );

  factory ReaderDashboard.fromJson(Map<String, dynamic> json) {
    return ReaderDashboard(
      overview:
          json['overview'] is Map
              ? ReaderOverview.fromJson(
                Map<String, dynamic>.from(json['overview'] as Map),
              )
              : ReaderOverview.empty(),
      continueReading:
          _asMapList(json['continueReading']).map(ReaderItem.fromJson).toList(),
      recentItems:
          _asMapList(json['recentItems']).map(ReaderItem.fromJson).toList(),
    );
  }

  final ReaderOverview overview;
  final List<ReaderItem> continueReading;
  final List<ReaderItem> recentItems;
}

class ReaderOverview {
  const ReaderOverview({required this.totalItems, required this.continueCount});

  factory ReaderOverview.empty() =>
      const ReaderOverview(totalItems: 0, continueCount: 0);

  factory ReaderOverview.fromJson(Map<String, dynamic> json) {
    return ReaderOverview(
      totalItems: _asInt(json['totalItems']),
      continueCount: _asInt(json['continueCount']),
    );
  }

  final int totalItems;
  final int continueCount;
}

int _asInt(dynamic value) => switch (value) {
  int() => value,
  num() => value.toInt(),
  _ => int.tryParse(value?.toString() ?? '') ?? 0,
};

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}
