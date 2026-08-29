class InitialSetupStatus {
  const InitialSetupStatus({
    required this.setupRequired,
    required this.setupAvailable,
    this.persistentStateEnabled = true,
  });

  final bool setupRequired;
  final bool setupAvailable;
  final bool persistentStateEnabled;

  factory InitialSetupStatus.fromJson(Map<String, dynamic> json) {
    return InitialSetupStatus(
      setupRequired: json['setupRequired'] == true,
      setupAvailable: json['setupAvailable'] == true,
      persistentStateEnabled: json['persistentStateEnabled'] != false,
    );
  }
}
