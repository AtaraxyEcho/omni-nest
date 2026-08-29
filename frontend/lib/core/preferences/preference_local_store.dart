import 'dart:convert';

import 'package:omninest/core/preferences/preference_snapshot.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferenceLocalStore {
  const PreferenceLocalStore();

  Future<PreferenceSnapshot?> readSnapshot(String userId, String scope) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_snapshotKey(userId, scope));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? PreferenceSnapshot.fromJson(decoded)
          : null;
    } on FormatException {
      await preferences.remove(_snapshotKey(userId, scope));
      return null;
    }
  }

  Future<void> writeSnapshot(String userId, PreferenceSnapshot snapshot) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _snapshotKey(userId, snapshot.scope),
      jsonEncode(snapshot.toJson()),
    );
  }

  Future<PreferenceMutation?> readPending(String userId, String scope) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_pendingKey(userId, scope));
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic>
          ? PreferenceMutation.fromJson(decoded)
          : null;
    } on FormatException {
      await preferences.remove(_pendingKey(userId, scope));
      return null;
    }
  }

  Future<void> writePending(
    String userId,
    String scope,
    PreferenceMutation mutation,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    if (mutation.isEmpty) {
      await preferences.remove(_pendingKey(userId, scope));
      return;
    }
    await preferences.setString(
      _pendingKey(userId, scope),
      jsonEncode(mutation.toJson()),
    );
  }

  Future<void> clearPending(String userId, String scope) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingKey(userId, scope));
  }

  Future<int?> readPendingDeletionVersion(String userId, String scope) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(_pendingDeletionKey(userId, scope));
  }

  Future<void> writePendingDeletionVersion(
    String userId,
    String scope,
    int version,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_pendingDeletionKey(userId, scope), version);
  }

  Future<void> clearPendingDeletion(String userId, String scope) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_pendingDeletionKey(userId, scope));
  }

  String _snapshotKey(String userId, String scope) {
    return 'preference.snapshot.$userId.$scope';
  }

  String _pendingKey(String userId, String scope) {
    return 'preference.pending.$userId.$scope';
  }

  String _pendingDeletionKey(String userId, String scope) {
    return 'preference.pending_delete.$userId.$scope';
  }
}
