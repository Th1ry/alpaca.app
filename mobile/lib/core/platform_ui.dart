import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Touch / gesture defaults tuned for Android vs desktop.
abstract final class PlatformUi {
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  static bool get isIOS => !kIsWeb && Platform.isIOS;

  static bool get isMobile => isAndroid || isIOS;

  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Mouse-wheel zoom on chart — desktop only.
  static bool get chartScrollZoomEnabled => isDesktop;

  static Duration get chartLongPressHold =>
      Duration(milliseconds: isAndroid ? 360 : 450);

  static double get chartPanTouchSlop => isAndroid ? 12.0 : 8.0;

  static double get chartTapSlop => isAndroid ? 14.0 : 10.0;

  static double get textScaleFactor => isMobile ? 1.0 : 0.80;

  static double get iconSize => isMobile ? 22.0 : 20.0;

  static double get minTouchTarget => isMobile ? 44.0 : 36.0;
}
