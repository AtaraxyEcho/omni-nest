import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/app/theme/feature/photos_colors.dart';
import 'package:omninest/features/photos/application/photo_controller.dart';
import 'package:omninest/features/photos/application/photo_batch_task_monitor.dart';
import 'package:omninest/features/photos/platform/photo_batch_web_download.dart';

/// 批量任务进度对话框
class BatchProgressDialog extends ConsumerStatefulWidget {
  const BatchProgressDialog({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<BatchProgressDialog> createState() =>
      _BatchProgressDialogState();
}

class _BatchProgressDialogState extends ConsumerState<BatchProgressDialog> {
  bool _isDownloading = false;

  Future<void> _downloadArchive() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final controller = ref.read(photoCenterControllerProvider.notifier);
      final ticket = await controller.getBatchDownloadTicket(widget.taskId);
      if (kIsWeb) {
        await downloadPhotoBatchInBrowser(
          url: ticket.url,
          fileName: ticket.fileName,
        );
        if (messenger.mounted) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.photosDownloadStarted)),
          );
        }
        return;
      }
      final location = await getSaveLocation(suggestedName: ticket.fileName);
      if (location == null) return;
      await controller.downloadBatchArchive(ticket, location.path);
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.photosArchiveSaved(location.path))),
        );
      }
    } on Exception {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.photosArchiveDownloadFailed)),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final monitor = ref.watch(photoBatchTaskMonitorProvider(widget.taskId));
    final snapshot = monitor.asData?.value;
    final task = snapshot?.task;
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      backgroundColor: context.photosColors.surfaceContainerHigh,
      title: Text(
        task == null ? l10n.photosLoading : _taskTitle(l10n, task.taskType),
        style: TextStyle(color: context.photosColors.onSurface),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task == null) ...[
            if (monitor.hasError)
              Text(
                l10n.photosTaskFailed,
                style: TextStyle(color: context.photosColors.danger),
              )
            else
              CircularProgressIndicator(),
          ] else if (task.isFailed) ...[
            Icon(
              Icons.error_outline,
              color: context.photosColors.danger,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              task.errorMessage ??
                  AppLocalizations.of(context).photosTaskFailed,
              style: TextStyle(color: context.photosColors.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ] else if (task.isCompleted) ...[
            Icon(
              Icons.check_circle_outline,
              color: context.photosColors.success,
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              AppLocalizations.of(
                context,
              ).photosProcessedItems(task.processedItems),
              style: TextStyle(color: context.photosColors.onSurfaceVariant),
            ),
          ] else ...[
            LinearProgressIndicator(
              value: task.progress,
              backgroundColor: context.photosColors.surfaceContainer,
              color: context.photosColors.primaryContainer,
            ),
            SizedBox(height: 12),
            Text(
              '${task.processedItems} / ${task.totalItems}',
              style: TextStyle(color: context.photosColors.onSurfaceVariant),
            ),
          ],
          if (snapshot?.refreshError != null) ...[
            const SizedBox(height: 12),
            Text(
              switch (snapshot?.issue) {
                PhotoBatchTaskMonitorIssue.notFound => l10n.photosTaskNotFound,
                PhotoBatchTaskMonitorIssue.timedOut =>
                  l10n.photosTaskMonitorTimedOut,
                null => l10n.photosTaskStatusRefreshFailed,
              },
              style: TextStyle(color: context.photosColors.danger),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
      actions: [
        if (snapshot?.issue != null || snapshot?.refreshError != null)
          TextButton.icon(
            onPressed:
                () => ref.invalidate(
                  photoBatchTaskMonitorProvider(widget.taskId),
                ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.photosRetryStatus),
          ),
        if (task == null)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.photosDone),
          )
        else if (task.isCompleted && task.taskType == 'DOWNLOAD') ...[
          TextButton(
            onPressed: _isDownloading ? null : () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).photosDone),
          ),
          FilledButton.icon(
            onPressed: _isDownloading ? null : _downloadArchive,
            icon:
                _isDownloading
                    ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.download_rounded),
            label: Text(AppLocalizations.of(context).photosSaveZip),
          ),
        ] else if (task.isCompleted || task.isFailed)
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).photosDone),
          )
        else
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context).photosRunInBackground),
          ),
      ],
    );
  }

  String _taskTitle(AppLocalizations l10n, String taskType) {
    return switch (taskType) {
      'TAG' => l10n.photosBatchAddTag,
      'MOVE' => l10n.photosMove,
      'UPDATE_DATE' => l10n.photosUpdateDate,
      'DOWNLOAD' => l10n.photosExportZip,
      _ => l10n.photosLoading,
    };
  }
}
