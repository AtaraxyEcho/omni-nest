import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/providers.dart';
import 'package:omninest/features/notifications/domain/notification_type.dart';

final notificationTypesProvider = FutureProvider<List<NotificationTypeConfig>>((
  ref,
) async {
  final api = ref.watch(notificationTypeApiProvider);
  try {
    return await api.list();
  } on Exception {
    return NotificationTypeConfig.fallbackTypes;
  }
});
