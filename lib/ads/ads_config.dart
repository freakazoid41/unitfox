import 'package:flutter/foundation.dart';

/// AdMob configuration for Unitfox.
///
/// Production IDs are live. Test IDs are kept for dry runs.
class AdsConfig {
  AdsConfig._();

  /// iOS App ID — must match ios/Runner/Info.plist (GADApplicationIdentifier).
  static const iosAppId = 'ca-app-pub-1088997129209291~8191655637';

  /// Android App ID — must match AndroidManifest.xml (APPLICATION_ID).
  static const androidAppId = 'ca-app-pub-1088997129209291~5559266208';

  /// iOS banner ad unit ID.
  static const iosBannerAdUnitId = 'ca-app-pub-1088997129209291/4361734608';

  /// Android banner ad unit ID.
  static const androidBannerAdUnitId = 'ca-app-pub-1088997129209291/6579191064';

  /// Google test banner (use when verifying the pipeline before going live).
  static const testBannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  /// Live ads. Set to false to force the Google test banner.
  static const isProduction = true;

  /// The banner unit to serve on the current platform.
  static String get bannerAdUnitId {
    if (!isProduction) return testBannerAdUnitId;
    return defaultTargetPlatform == TargetPlatform.android
        ? androidBannerAdUnitId
        : iosBannerAdUnitId;
  }

  /// google_mobile_ads has no web support — gate every surface with this.
  static bool get enabled => !kIsWeb;
}