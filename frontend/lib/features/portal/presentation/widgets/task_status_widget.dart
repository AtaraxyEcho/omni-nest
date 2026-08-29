import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:omninest/app/l10n/app_localizations.dart';

class TaskStatusWidget extends StatelessWidget {
  const TaskStatusWidget({
    required this.running,
    required this.queued,
    required this.failed,
    super.key,
  });
  final int running;
  final int queued;
  final int failed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.go('/admin'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.portalAdmin, style: theme.textTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 12),
              _StatusLine(
                label: l10n.portalTaskRunning,
                count: running,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 4),
              _StatusLine(
                label: l10n.portalTaskQueued,
                count: queued,
                color: colorScheme.tertiary,
              ),
              const SizedBox(height: 4),
              _StatusLine(
                label: l10n.portalTaskFailed,
                count: failed,
                color:
                    failed > 0
                        ? colorScheme.error
                        : colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: theme.textTheme.bodySmall),
        const Spacer(),
        Text(
          '$count',
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
