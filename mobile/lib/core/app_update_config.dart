/// In-app OTA — edit [defaultManifestUrl] when releasing a new build.
class AppUpdateConfig {
  AppUpdateConfig._();

  static const defaultManifestUrl =
      'https://raw.githubusercontent.com/Th1ry/alpaca.app/main/releases/app-update.json';

  static const manifestUrl = String.fromEnvironment(
    'APP_UPDATE_MANIFEST_URL',
    defaultValue: defaultManifestUrl,
  );

  static const autoCheckIntervalHours = 6;
}
