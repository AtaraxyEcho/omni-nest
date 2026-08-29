/// 照片模块提供给跨 Feature 仪表盘的只读契约。
library;

export 'package:omninest/features/photos/application/photo_controller.dart'
    show photoDashboardProvider;
export 'package:omninest/features/photos/domain/photo.dart'
    show PhotoDashboard, PhotoItem;
