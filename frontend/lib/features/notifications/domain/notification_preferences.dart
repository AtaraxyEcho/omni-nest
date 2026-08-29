/// 通知偏好设置模型。
class NotificationPreferences {
  const NotificationPreferences({
    this.enabled = true,
    this.types = const {},
    this.quietHours = const QuietHours(),
    this.sound = true,
    this.showPreview = true,
    this.emailNotification = false,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    final typesRaw = json['types'] as Map<String, dynamic>? ?? {};
    final types = typesRaw.map(
      (key, value) => MapEntry(key, value as bool? ?? true),
    );
    return NotificationPreferences(
      enabled: json['enabled'] as bool? ?? true,
      types: types,
      quietHours:
          json['quietHours'] is Map<String, dynamic>
              ? QuietHours.fromJson(json['quietHours'] as Map<String, dynamic>)
              : const QuietHours(),
      sound: json['sound'] as bool? ?? true,
      showPreview: json['showPreview'] as bool? ?? true,
      emailNotification: json['emailNotification'] as bool? ?? false,
    );
  }

  final bool enabled;
  final Map<String, bool> types;
  final QuietHours quietHours;
  final bool sound;
  final bool showPreview;
  final bool emailNotification;

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'types': types,
      'quietHours': quietHours.toJson(),
      'sound': sound,
      'showPreview': showPreview,
      'emailNotification': emailNotification,
    };
  }

  NotificationPreferences copyWith({
    bool? enabled,
    Map<String, bool>? types,
    QuietHours? quietHours,
    bool? sound,
    bool? showPreview,
    bool? emailNotification,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      types: types ?? this.types,
      quietHours: quietHours ?? this.quietHours,
      sound: sound ?? this.sound,
      showPreview: showPreview ?? this.showPreview,
      emailNotification: emailNotification ?? this.emailNotification,
    );
  }

  /// 获取指定类型是否启用（未配置默认 true）。
  bool isTypeEnabled(String typeCode) {
    return types[typeCode] ?? true;
  }
}

/// 免打扰时段配置。
class QuietHours {
  const QuietHours({
    this.enabled = false,
    this.start = '22:00',
    this.end = '08:00',
  });

  factory QuietHours.fromJson(Map<String, dynamic> json) {
    return QuietHours(
      enabled: json['enabled'] as bool? ?? false,
      start: json['start']?.toString() ?? '22:00',
      end: json['end']?.toString() ?? '08:00',
    );
  }

  final bool enabled;
  final String start;
  final String end;

  Map<String, dynamic> toJson() {
    return {'enabled': enabled, 'start': start, 'end': end};
  }
}
