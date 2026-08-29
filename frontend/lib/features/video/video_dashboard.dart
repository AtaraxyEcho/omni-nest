/// 影视模块提供给跨 Feature 仪表盘的只读契约。
library;

export 'package:omninest/features/video/application/movie_controller.dart'
    show movieDashboardProvider;
export 'package:omninest/features/video/domain/movie_models.dart'
    show MovieContinueWatching, MovieDashboard, MovieVideoItem;
