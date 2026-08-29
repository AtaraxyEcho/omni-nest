import 'package:flutter/material.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/core/widgets/workbench_panel.dart';

class ProfileSecurityActionsPanel extends StatelessWidget {
  const ProfileSecurityActionsPanel({
    required this.onChangePassword,
    super.key,
  });

  final VoidCallback onChangePassword;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return WorkbenchPanel(
      padding: const EdgeInsets.all(12),
      child: ListTile(
        leading: const Icon(Icons.lock_outline_rounded),
        title: Text(l10n.profileChangePassword),
        subtitle: Text(l10n.profileChangePasswordSubtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onChangePassword,
      ),
    );
  }
}

class ProfileAboutPanel extends StatelessWidget {
  const ProfileAboutPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return WorkbenchPanel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hub_outlined, size: 36, color: scheme.primary),
          const SizedBox(height: 18),
          Text(
            'OmniNest',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.settingsAboutHint,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
