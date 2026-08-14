import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/user_role.dart';

abstract interface class ProfileRepository {
  Future<UserRole?> fetchRole(String userId);
}

class SupabaseProfileRepository implements ProfileRepository {
  SupabaseProfileRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<UserRole?> fetchRole(String userId) async {
    try {
      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      if (profile == null) return null;
      return parseUserRole(profile['role']);
    } on UnsupportedUserRoleException {
      rethrow;
    } on PostgrestException catch (error) {
      throw ProfileRepositoryException(error.message);
    } catch (_) {
      throw const ProfileRepositoryException(
        'The profile request failed unexpectedly.',
      );
    }
  }
}

class ProfileRepositoryException implements Exception {
  const ProfileRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
