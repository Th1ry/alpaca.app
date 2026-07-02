/// In-app OTA update — manifest hosted on GitHub [releases/app-update.json].
class AppUpdateConfig {
  AppUpdateConfig._();

  /// Raw JSON URL for update manifest.
  static const manifestUrl = String.fromEnvironment(
    'APP_UPDATE_MANIFEST_URL',
    defaultValue:
        'https://raw.githubusercontent.com/Th1ry/alpaca.app/main/releases/app-update.json',
  );

  /// Minimum hours between automatic background checks.
  static const autoCheckIntervalHours = 6;
}
