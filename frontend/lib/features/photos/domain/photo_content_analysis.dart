/// 照片图像分析结果。
class PhotoContentAnalysis {
  const PhotoContentAnalysis({
    required this.status,
    required this.pipelineVersion,
    required this.completedAt,
    required this.labels,
  });

  factory PhotoContentAnalysis.fromJson(Map<String, dynamic> json) {
    final rawLabels = json['labels'];
    return PhotoContentAnalysis(
      status: json['status']?.toString() ?? 'UNKNOWN',
      pipelineVersion: json['pipelineVersion']?.toString(),
      completedAt:
          DateTime.tryParse(json['completedAt']?.toString() ?? '')?.toLocal(),
      labels:
          rawLabels is List
              ? rawLabels
                  .whereType<Map>()
                  .map(
                    (item) => PhotoContentLabel.fromJson(
                      Map<String, dynamic>.from(item),
                    ),
                  )
                  .toList(growable: false)
              : const [],
    );
  }

  final String status;
  final String? pipelineVersion;
  final DateTime? completedAt;
  final List<PhotoContentLabel> labels;

  Map<String, List<PhotoContentLabel>> get labelsByNamespace {
    final groups = <String, List<PhotoContentLabel>>{};
    for (final label in labels) {
      groups.putIfAbsent(label.namespace, () => []).add(label);
    }
    return groups.map(
      (key, value) =>
          MapEntry(key, List<PhotoContentLabel>.unmodifiable(value)),
    );
  }
}

/// 照片图像分析自动标签。
class PhotoContentLabel {
  const PhotoContentLabel({
    required this.id,
    required this.namespace,
    required this.code,
    required this.confidence,
    required this.source,
    required this.state,
    required this.boxes,
  });

  factory PhotoContentLabel.fromJson(Map<String, dynamic> json) {
    final rawBoxes = json['boxes'];
    return PhotoContentLabel(
      id: json['id']?.toString() ?? '',
      namespace: json['namespace']?.toString() ?? 'UNKNOWN',
      code: json['code']?.toString() ?? '',
      confidence:
          json['confidence'] is num
              ? (json['confidence'] as num).toDouble()
              : 0,
      source: json['source']?.toString() ?? 'unknown',
      state: json['state']?.toString() ?? 'AUTO',
      boxes:
          rawBoxes is List
              ? rawBoxes
                  .whereType<Map>()
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList(growable: false)
              : const [],
    );
  }

  final String id;
  final String namespace;
  final String code;
  final double confidence;
  final String source;
  final String state;
  final List<Map<String, dynamic>> boxes;
}
