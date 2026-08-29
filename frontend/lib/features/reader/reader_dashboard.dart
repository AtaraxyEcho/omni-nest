/// 阅读模块提供给跨 Feature 仪表盘的只读契约。
library;

export 'package:omninest/features/reader/application/reader_controller.dart'
    show readerDashboardProvider;
export 'package:omninest/features/reader/domain/reader_models.dart'
    show ReaderDashboard, ReaderItem;
