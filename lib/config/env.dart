import 'dart:io';

class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      !supabaseUrl.contains('YOUR_PROJECT') &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';

  /// GA4 iOS app data stream measurement ID (G-XXXXXXXX).
  static const gaIosMeasurementId = String.fromEnvironment(
    'GA_IOS_MEASUREMENT_ID',
    defaultValue: '',
  );

  /// GA4 Android app data stream measurement ID (G-XXXXXXXX).
  static const gaAndroidMeasurementId = String.fromEnvironment(
    'GA_ANDROID_MEASUREMENT_ID',
    defaultValue: '',
  );

  /// Measurement Protocol API secret for the iOS app stream.
  /// GA4 Admin → Data streams → iOS app → Measurement Protocol API secrets.
  static const gaIosApiSecret = String.fromEnvironment(
    'GA_IOS_API_SECRET',
    defaultValue: '',
  );

  /// Measurement Protocol API secret for the Android app stream.
  /// GA4 Admin → Data streams → Android app → Measurement Protocol API secrets.
  static const gaAndroidApiSecret = String.fromEnvironment(
    'GA_ANDROID_API_SECRET',
    defaultValue: '',
  );

  static bool get isAnalyticsConfigured => mobileAnalyticsConfig != null;

  /// Active GA4 mobile stream for the current platform.
  static ({String measurementId, String apiSecret})? get mobileAnalyticsConfig {
    if (Platform.isIOS &&
        gaIosMeasurementId.isNotEmpty &&
        gaIosApiSecret.isNotEmpty) {
      return (measurementId: gaIosMeasurementId, apiSecret: gaIosApiSecret);
    }
    if (Platform.isAndroid &&
        gaAndroidMeasurementId.isNotEmpty &&
        gaAndroidApiSecret.isNotEmpty) {
      return (
        measurementId: gaAndroidMeasurementId,
        apiSecret: gaAndroidApiSecret,
      );
    }
    return null;
  }

  /// Add this URL in Supabase → Authentication → URL Configuration → Redirect URLs.
  static const passwordResetRedirectUrl =
      'com.trackpepper.trackPepper://reset-password';
}
