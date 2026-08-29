import 'fullscreen_helper_stub.dart'
    if (dart.library.html) 'fullscreen_helper_web.dart'
    as platform;

bool get isFullscreen => platform.FullscreenHelperWeb.isFullscreenEnabled;

void toggleFullscreen() {
  if (platform.FullscreenHelperWeb.isFullscreenEnabled) {
    platform.FullscreenHelperWeb.exitFullscreen();
  } else {
    platform.FullscreenHelperWeb.enterFullscreen(
      platform.FullscreenHelperWeb.documentElement,
    );
  }
}
