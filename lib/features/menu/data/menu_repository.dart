import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/menu_item.dart';

abstract interface class MenuRepository {
  Future<List<MenuItem>> fetchForKitchen(String kitchenId);

  Future<MenuItem> create(String kitchenId, MenuItemDraft draft);

  Future<MenuItem> update(MenuItem item);

  Future<void> delete(String menuItemId);
}

class SupabaseMenuRepository implements MenuRepository {
  SupabaseMenuRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MenuItem>> fetchForKitchen(String kitchenId) async {
    try {
      final rows = await _client
          .from('menu_items')
          .select()
          .eq('kitchen_id', kitchenId)
          .order('created_at', ascending: false);
      return rows.map(MenuItem.fromMap).toList(growable: false);
    } on PostgrestException catch (error) {
      throw MenuRepositoryException(error.message);
    }
  }

  @override
  Future<MenuItem> create(String kitchenId, MenuItemDraft draft) async {
    try {
      final row = await _client
          .from('menu_items')
          .insert(draft.toInsertMap(kitchenId))
          .select()
          .single();
      return MenuItem.fromMap(row);
    } on PostgrestException catch (error) {
      throw MenuRepositoryException(error.message);
    }
  }

  @override
  Future<MenuItem> update(MenuItem item) async {
    try {
      final row = await _client
          .from('menu_items')
          .update(item.toUpdateMap())
          .eq('id', item.id)
          .select()
          .single();
      return MenuItem.fromMap(row);
    } on PostgrestException catch (error) {
      throw MenuRepositoryException(error.message);
    }
  }

  @override
  Future<void> delete(String menuItemId) async {
    try {
      await _client.from('menu_items').delete().eq('id', menuItemId);
    } on PostgrestException catch (error) {
      if (error.code == '23503') {
        throw const MenuItemReferencedException();
      }
      throw MenuRepositoryException(error.message);
    }
  }
}

class MenuRepositoryException implements Exception {
  const MenuRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

class MenuItemReferencedException extends MenuRepositoryException {
  const MenuItemReferencedException()
    : super('This menu item is referenced by an order.');
}

enum MenuDeleteOutcome { deleted, archived }

Future<MenuDeleteOutcome> deleteMenuItemSafely(
  MenuRepository repository,
  MenuItem item,
) async {
  try {
    await repository.delete(item.id);
    return MenuDeleteOutcome.deleted;
  } on MenuItemReferencedException {
    await repository.update(item.copyWith(isAvailable: false));
    return MenuDeleteOutcome.archived;
  }
}
