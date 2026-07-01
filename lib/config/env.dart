class Env {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://YOUR_PROJECT.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  static bool get hasSupabaseCredentials =>
      !supabaseUrl.contains('YOUR_PROJECT') &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';

  static bool get isConfigured => hasSupabaseCredentials;

  /// Add this URL in Supabase → Authentication → URL Configuration → Redirect URLs.
  static const passwordResetRedirectUrl =
      'com.mnew.trackPepper://reset-password';
}
