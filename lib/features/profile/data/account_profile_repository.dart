import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/validation/bangladesh_phone.dart';
import '../domain/user_role.dart';

class AccountProfile {
  const AccountProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.role,
    required this.email,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final UserRole role;
  final String email;

  AccountProfile copyWith({String? phone}) => AccountProfile(
    id: id,
    name: name,
    phone: phone ?? this.phone,
    address: address,
    role: role,
    email: email,
  );
}

abstract interface class AccountProfileRepository {
  Future<AccountProfile> fetchCurrent();
  Future<AccountProfile> updatePhone(String phone);
}

class SupabaseAccountProfileRepository implements AccountProfileRepository {
  SupabaseAccountProfileRepository(this._client);

  final SupabaseClient _client;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AccountProfileException('Sign in again.');
    return id;
  }

  @override
  Future<AccountProfile> fetchCurrent() async {
    try {
      final row = await _client
          .from('profiles')
          .select('id,name,phone,address,role')
          .eq('id', _userId)
          .single();
      return _map(row);
    } on AccountProfileException {
      rethrow;
    } on PostgrestException {
      throw const AccountProfileException(
        'Could not load your profile. Please retry.',
      );
    }
  }

  @override
  Future<AccountProfile> updatePhone(String phone) async {
    final normalized = normalizeBangladeshPhone(phone);
    if (!isValidBangladeshPhone(normalized)) {
      throw const AccountProfileException(
        'Enter a valid Bangladeshi mobile number.',
      );
    }
    try {
      final row = await _client
          .from('profiles')
          .update({'phone': normalized})
          .eq('id', _userId)
          .select('id,name,phone,address,role')
          .single();
      return _map(row);
    } on AccountProfileException {
      rethrow;
    } on PostgrestException {
      throw const AccountProfileException(
        'Could not update your phone number. Please retry.',
      );
    }
  }

  AccountProfile _map(Map<String, dynamic> row) => AccountProfile(
    id: row['id'] as String,
    name: row['name'] as String,
    phone: row['phone'] as String,
    address: row['address'] as String,
    role: parseUserRole(row['role']),
    email: _client.auth.currentUser?.email ?? '',
  );
}

class AccountProfileException implements Exception {
  const AccountProfileException(this.message);
  final String message;
  @override
  String toString() => message;
}
