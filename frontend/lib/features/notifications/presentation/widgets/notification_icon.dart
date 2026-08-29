import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/global_theme_colors.dart';
import 'package:omninest/features/notifications/application/notification_controller.dart';

/// 显示通知入口和未读数量。
class NotificationIcon extends ConsumerWidget {
  const NotificationIcon({super.key, this.size = 20, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);
    final colors = context.globalColors;
    return IconButton(
      tooltip: AppLocalizations.of(context).notificationTitle,
      onPressed: () => context.go('/notifications'),
      icon: Badge(
        isLabelVisible: unreadCount > 0,
        label: Text(
          unreadCount > 99 ? '99+' : '$unreadCount',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: colors.onError,
          ),
        ),
        backgroundColor: colors.error,
        child: Icon(Icons.notifications_none_rounded, size: size, color: color),
      ),
    );
  }
}
