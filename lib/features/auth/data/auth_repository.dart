import 'package:supabase_flutter/supabase_flutter.dart';

class AuthSession {
  const AuthSession({required this.userId});

  final String userId;
}

abstract interface class AuthRepository {
  AuthSession? get currentSession;

  Stream<AuthSession?> get sessionChanges;

  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AuthSession? get currentSession => _toSession(_client.auth.currentSession);

  @override
  Stream<AuthSession?> get sessionChanges =>
      _client.auth.onAuthStateChange.map((state) => _toSession(state.session));

  @override
  Future<void> signOut() => _client.auth.signOut();

  AuthSession? _toSession(Session? session) {
    if (session == null) return null;
    return AuthSession(userId: session.user.id);
  }
}
