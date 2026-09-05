import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/appearance/application/appearance_controller.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/locale/application/locale_controller.dart';
import 'package:omninest/app/theme/global_theme_colors.dart';
import 'package:omninest/core/auth/auth_controller.dart';

/// 右上角头像下拉菜单组件。
///
/// 显示用户头像，并提供个人中心、存储、管理和退出入口。
class UserAvatarMenu extends ConsumerWidget {
  const UserAvatarMenu({
    super.key,
    this.size = 36,
    this.directToProfile = false,
  });

  /// 头像尺寸（宽高），默认 36。
  final double size;

  /// 是否直接进入个人中心，移动端全局顶部栏使用该模式。
  final bool directToProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authSessionProvider);
    final themeMode = ref.watch(appearanceControllerProvider);
    final languageCode = ref.watch(localeControllerProvider);
    final user = authState.asData?.value.user;
    final appColors = context.globalColors;
    final sourceTheme = Theme.of(context);
    final sharedMenuTheme = sourceTheme.copyWith(
      colorScheme: sourceTheme.colorScheme.copyWith(
        surface: appColors.surface,
        surfaceContainerLow: appColors.surfaceContainerLow,
        surfaceContainer: appColors.surfaceContainer,
        surfaceContainerHigh: appColors.surfaceContainerHigh,
        surfaceContainerHighest: appColors.surfaceContainerHighest,
        onSurface: appColors.onSurface,
        onSurfaceVariant: appColors.onSurfaceVariant,
        primary: appColors.primary,
        error: appColors.error,
        outline: appColors.outline,
        outlineVariant: appColors.outlineVariant,
      ),
    );

    final displayName = user?.displayName ?? user?.username ?? '?';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final avatarUrl = user?.avatarUrl;
    final role = user?.role ?? 'MEMBER';

    final avatar = _AvatarWidget(
      avatarUrl: avatarUrl,
      initial: initial,
      size: size,
    );
    if (directToProfile) {
      return SizedBox.square(
        dimension: 48,
        child: Tooltip(
          message: l10n.coreProfile,
          child: InkResponse(
            onTap: () => context.push('/profile'),
            radius: 24,
            customBorder: const CircleBorder(),
            child: Center(child: avatar),
          ),
        ),
      );
    }
    return Theme(
      data: sharedMenuTheme,
      child: PopupMenuButton<_MenuAction>(
        tooltip: l10n.coreProfile,
        offset: const Offset(0, 48),
        color: appColors.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        onSelected: (action) => _handleAction(context, ref, action),
        itemBuilder:
            (context) => [
              // 用户信息头部（不可点击）
              PopupMenuItem<_MenuAction>(
                enabled: false,
                padding: EdgeInsets.zero,
                child: _UserHeader(
                  displayName: displayName,
                  username: user?.username ?? '',
                  role: role,
                  avatarUrl: avatarUrl,
                  initial: initial,
                ),
              ),
              const PopupMenuDivider(),
              // 个人中心
              PopupMenuItem<_MenuAction>(
                value: _MenuAction.profile,
                child: _MenuItem(
                  icon: Icons.person_outline_rounded,
                  title: l10n.coreProfile,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<_MenuAction>(
                value: _MenuAction.themeSystem,
                child: _MenuItem(
                  icon: Icons.brightness_auto_outlined,
                  title: l10n.settingsThemeSystem,
                  selected: themeMode == ThemeMode.system,
                ),
              ),
              PopupMenuItem<_MenuAction>(
                value: _MenuAction.themeLight,
                child: _MenuItem(
                  icon: Icons.light_mode_outlined,
                  title: l10n.settingsThemeLight,
                  selected: themeMode == ThemeMode.light,
                ),
              ),
              PopupMenuItem<_MenuAction>(
                value: _MenuAction.themeDark,
                child: _MenuItem(
                  icon: Icons.dark_mode_outlined,
                  title: l10n.settingsThemeDark,
                  selected: themeMode == ThemeMode.dark,
                ),
              ),
              // 语言开关：开启为中文界面，关闭为英文界面
              PopupMenuItem<_MenuAction>(
                value: _MenuAction.language,
                child: _LanguageToggleItem(isChinese: languageCode == 'zh'),
              ),
              const PopupMenuDivider(),
              // 存储空间
              PopupMenuItem<_MenuAction>(
                value: _MenuAction.storage,
                child: _MenuItem(
                  icon: Icons.cloud_outlined,
                  title: l10n.coreStorage,
                ),
              ),
              // 管理后台（仅管理员可见）
              if (role == 'SUPER_ADMIN' || role == 'ADMIN')
                PopupMenuItem<_MenuAction>(
                  value: _MenuAction.admin,
                  child: _MenuItem(
                    icon: Icons.admin_panel_settings_outlined,
                    title: l10n.coreAdmin,
                  ),
                ),
              const PopupMenuDivider(),
              // 退出登录
              PopupMenuItem<_MenuAction>(
                value: _MenuAction.signOut,
                child: _MenuItem(
                  icon: Icons.logout_rounded,
                  title: l10n.coreSignOut,
                  isDestructive: true,
                ),
              ),
            ],
        child: avatar,
      ),
    );
  }

  void _handleAction(BuildContext context, WidgetRef ref, _MenuAction action) {
    switch (action) {
      case _MenuAction.profile:
        context.go('/profile');
      case _MenuAction.themeSystem:
        unawaited(
          ref
              .read(appearanceControllerProvider.notifier)
              .setThemeMode(ThemeMode.system),
        );
      case _MenuAction.themeLight:
        unawaited(
          ref
              .read(appearanceControllerProvider.notifier)
              .setThemeMode(ThemeMode.light),
        );
      case _MenuAction.themeDark:
        unawaited(
          ref
              .read(appearanceControllerProvider.notifier)
              .setThemeMode(ThemeMode.dark),
        );
      case _MenuAction.language:
        final current = ref.read(localeControllerProvider);
        unawaited(
          ref
              .read(localeControllerProvider.notifier)
              .setLanguage(current == 'zh' ? 'en' : 'zh'),
        );
      case _MenuAction.storage:
        context.go('/files');
      case _MenuAction.admin:
        context.go('/admin');
      case _MenuAction.signOut:
        ref.read(authSessionProvider.notifier).clearSession();
    }
  }
}

enum _MenuAction {
  profile,
  themeSystem,
  themeLight,
  themeDark,
  language,
  storage,
  admin,
  signOut,
}

/// 菜单项组件。
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.icon,
    required this.title,
    this.isDestructive = false,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final bool isDestructive;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = isDestructive ? colors.error : colors.onSurface;
    return ListTile(
      leading: Icon(icon, size: 20, color: color),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
      trailing:
          selected
              ? Icon(Icons.check_rounded, size: 18, color: colors.primary)
              : null,
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// 语言开关行：开关开启表示中文界面，关闭表示英文界面。
/// 行内 Switch 仅承载状态展示，点击统一交给菜单选中逻辑处理。
class _LanguageToggleItem extends StatelessWidget {
  const _LanguageToggleItem({required this.isChinese});

  final bool isChinese;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(Icons.language_rounded, size: 20, color: colors.onSurface),
      title: Text(
        l10n.settingsLanguage,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: colors.onSurface,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isChinese
                ? l10n.settingsLanguageChinese
                : l10n.settingsLanguageEnglish,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          IgnorePointer(child: Switch(value: isChinese, onChanged: (_) {})),
        ],
      ),
      dense: true,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// 头像显示组件，优先网络图片，降级为首字母渐变。
class _AvatarWidget extends StatelessWidget {
  const _AvatarWidget({
    required this.avatarUrl,
    required this.initial,
    this.size = 36,
  });

  final String? avatarUrl;
  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content =
        avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _AvatarFallback(initial: initial),
            )
            : _AvatarFallback(initial: initial);
    // 显式 ClipOval 保证任意平台上头像均为正圆，边框以覆盖层绘制。
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipOval(
              child: ColoredBox(
                color: theme.colorScheme.surfaceContainerHighest,
                child: content,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 首字母渐变降级头像。
class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initial});

  final String initial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

/// 菜单头部：头像 + 用户名 + 角色标签。
class _UserHeader extends StatelessWidget {
  const _UserHeader({
    required this.displayName,
    required this.username,
    required this.role,
    required this.avatarUrl,
    required this.initial,
  });

  final String displayName;
  final String username;
  final String role;
  final String? avatarUrl;
  final String initial;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final roleLabel = switch (role) {
      'SUPER_ADMIN' => l10n.coreRoleSuperAdmin,
      'ADMIN' => l10n.coreRoleAdmin,
      _ => l10n.coreRoleMember,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            child:
                avatarUrl != null && avatarUrl!.isNotEmpty
                    ? Image.network(
                      avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, _, _) => _AvatarFallback(initial: initial),
                    )
                    : _AvatarFallback(initial: initial),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        username,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RoleBadge(role: role, label: roleLabel),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 角色标签。
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.label});

  final String role;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (role) {
      'SUPER_ADMIN' => theme.colorScheme.error,
      'ADMIN' => theme.colorScheme.tertiary,
      _ => theme.colorScheme.outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}
