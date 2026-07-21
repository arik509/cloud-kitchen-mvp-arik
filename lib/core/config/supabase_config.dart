class SupabaseConfig {
  const SupabaseConfig._({
    required this.url,
    required this.publishableKey,
  });

  final Uri url;
  final String publishableKey;

  factory SupabaseConfig.fromEnvironment() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const publishableKey = String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    );
    return SupabaseConfig.fromValues(
      url: url,
      publishableKey: publishableKey,
    );
  }

  factory SupabaseConfig.fromValues({
    required String url,
    required String publishableKey,
  }) {
    final normalizedUrl = url.trim();
    final normalizedKey = publishableKey.trim();
    final uri = Uri.tryParse(normalizedUrl);

    if (normalizedUrl.isEmpty || normalizedKey.isEmpty) {
      throw const ConfigurationException(
        'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required.',
      );
    }
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const ConfigurationException(
        'SUPABASE_URL must be a valid HTTPS URL.',
      );
    }
    if (!normalizedKey.startsWith('sb_publishable_')) {
      throw const ConfigurationException(
        'SUPABASE_PUBLISHABLE_KEY must be a Supabase publishable key.',
      );
    }
    return SupabaseConfig._(url: uri, publishableKey: normalizedKey);
  }
}

class ConfigurationException implements Exception {
  const ConfigurationException(this.message);

  final String message;

  @override
  String toString() => message;
}
