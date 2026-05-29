class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const oneSignalAppId = String.fromEnvironment('ONESIGNAL_APP_ID');
  static const updateManifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: 'https://<owner>.github.io/<repo>/latest.json',
  );

  static void validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'Missing runtime config. Set SUPABASE_URL and SUPABASE_ANON_KEY using --dart-define.',
      );
    }
  }
}
