/// Portal 用户偏好。
class PortalPreferences {
  const PortalPreferences({this.immersiveModeEnabled = false});

  factory PortalPreferences.fromJson(Map<String, dynamic> json) {
    return PortalPreferences(
      immersiveModeEnabled: json['immersiveModeEnabled'] as bool? ?? false,
    );
  }

  final bool immersiveModeEnabled;

  PortalPreferences copyWith({bool? immersiveModeEnabled}) {
    return PortalPreferences(
      immersiveModeEnabled: immersiveModeEnabled ?? this.immersiveModeEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {'immersiveModeEnabled': immersiveModeEnabled};
  }
}
