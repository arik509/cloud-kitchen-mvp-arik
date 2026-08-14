import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class PushTokenRepository {
  Future<void> register({required String token, required String platform});
  Future<void> unregister(String token);
}

class SupabasePushTokenRepository implements PushTokenRepository {
  SupabasePushTokenRepository(this._client);
  final SupabaseClient _client;

  void _requireSession() {
    if (_client.auth.currentUser == null) {
      throw const PushTokenException('Sign in before enabling notifications.');
    }
  }

  @override
  Future<void> register({
    required String token,
    required String platform,
  }) async {
    _requireSession();
    try {
      await _client.rpc(
        'register_push_token',
        params: {'p_token': token, 'p_platform': platform},
      );
    } on PostgrestException catch (_) {
      throw const PushTokenException(
        'Could not register this device for notifications.',
      );
    }
  }

  @override
  Future<void> unregister(String token) async {
    _requireSession();
    try {
      await _client.rpc('unregister_push_token', params: {'p_token': token});
    } on PostgrestException catch (_) {
      throw const PushTokenException(
        'Could not unregister this device from notifications.',
      );
    }
  }
}

class PushTokenException implements Exception {
  const PushTokenException(this.message);
  final String message;
  @override
  String toString() => message;
}
