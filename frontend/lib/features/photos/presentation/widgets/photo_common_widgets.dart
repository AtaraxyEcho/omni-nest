import 'package:omninest/app/l10n/app_localizations.dart';
import 'package:omninest/features/photos/application/photo_center_models.dart';
import 'package:omninest/features/photos/domain/photo_group.dart';

/// 将导入流程提示映射为当前语言的文案。
String photoImportNoticeText(
  AppLocalizations l10n,
  PhotoImportNotice notice, {
  String? detail,
}) {
  if (notice == PhotoImportNotice.backendFailed &&
      detail != null &&
      detail.trim().isNotEmpty) {
    return detail;
  }
  return switch (notice) {
    PhotoImportNotice.completedNotVisible =>
      l10n.photosImportCompletedNotVisible,
    PhotoImportNotice.stillProcessing => l10n.photosImportStillProcessing,
    PhotoImportNotice.backendFailed => l10n.photosImportBackendFailed,
  };
}

/// 分组维度标签。
String photoGroupByLabel(AppLocalizations l10n, GroupBy by) {
  return switch (by) {
    GroupBy.date => l10n.photosGroupByDate,
    GroupBy.location => l10n.photosGroupByLocation,
    GroupBy.format => l10n.photosGroupByFormat,
    GroupBy.tag => l10n.photosGroupByTag,
  };
}
