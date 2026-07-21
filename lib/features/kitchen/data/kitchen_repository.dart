import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/kitchen.dart';

abstract interface class KitchenRepository {
  Future<Kitchen?> fetchForOwner(String ownerId);

  Future<Kitchen> create(String ownerId, KitchenDraft draft);
}

class SupabaseKitchenRepository implements KitchenRepository {
  SupabaseKitchenRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Kitchen?> fetchForOwner(String ownerId) async {
    try {
      final row = await _client
          .from('kitchens')
          .select()
          .eq('owner_id', ownerId)
          .maybeSingle();
      return row == null ? null : Kitchen.fromMap(row);
    } on PostgrestException catch (error) {
      throw KitchenRepositoryException(error.message);
    }
  }

  @override
  Future<Kitchen> create(String ownerId, KitchenDraft draft) async {
    try {
      final row = await _client
          .from('kitchens')
          .insert(draft.toInsertMap(ownerId))
          .select()
          .single();
      return Kitchen.fromMap(row);
    } on PostgrestException catch (error) {
      throw KitchenRepositoryException(error.message);
    }
  }
}

class KitchenRepositoryException implements Exception {
  const KitchenRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
