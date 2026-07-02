import 'platform_ui.dart';

/// Layout tokens; scales differ on phone vs desktop window.
class DisplayConfig {
  static const nativeWidth = 1280;
  static const nativeHeight = 2856;
  static const aspectRatio = nativeWidth / nativeHeight;

  static const windowWidth = 412.0;
  static const windowHeight = windowWidth * nativeHeight / nativeWidth;

  static double get textScale => PlatformUi.textScaleFactor;
  static double get iconSize => PlatformUi.iconSize;
}
