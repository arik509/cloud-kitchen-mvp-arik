import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/kitchen.dart';

abstract interface class KitchenRepository {
  Future<Kitchen?> fetchForOwner(String ownerId);

  Future<Kitchen> create(String ownerId, KitchenDraft draft);

  Future<Kitchen> update(String ownerId, Kitchen kitchen);
}

class SupabaseKitchenRepository implements KitchenRepository {
  SupabaseKitchenRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Kitchen?> fetchForOwner(String ownerId) async {
    try {
      final row = await _client
          .from('kitchens')
          .select(
            'id,owner_id,name,address,latitude,longitude,image_path,is_active',
          )
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
          .select(
            'id,owner_id,name,address,latitude,longitude,image_path,is_active',
          )
          .single();
      return Kitchen.fromMap(row);
    } on PostgrestException catch (error) {
      throw KitchenRepositoryException(error.message);
    }
  }

  @override
  Future<Kitchen> update(String ownerId, Kitchen kitchen) async {
    verifyKitchenOwnership(ownerId, kitchen);
    try {
      final row = await _client
          .from('kitchens')
          .update(kitchen.toUpdateMap())
          .eq('id', kitchen.id)
          .eq('owner_id', ownerId)
          .select(
            'id,owner_id,name,address,latitude,longitude,image_path,is_active',
          )
          .single();
      return Kitchen.fromMap(row);
    } on PostgrestException catch (error) {
      throw KitchenRepositoryException(error.message);
    }
  }
}

void verifyKitchenOwnership(String ownerId, Kitchen kitchen) {
  if (kitchen.ownerId != ownerId) {
    throw const KitchenRepositoryException(
      'You can update only your own kitchen.',
    );
  }
}

class KitchenRepositoryException implements Exception {
  const KitchenRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
