import 'package:supabase_flutter/supabase_flutter.dart';

import '../../kitchen/domain/kitchen.dart';
import '../../menu/domain/menu_item.dart';
import '../domain/nearby_kitchen.dart';

abstract interface class CustomerCatalogRepository {
  Future<List<Kitchen>> fetchKitchensWithCoordinates();

  Future<Map<String, KitchenImageReference>> fetchRepresentativeImages();

  Future<List<MenuItem>> fetchAvailableMenuItems(String kitchenId);
}

class SupabaseCustomerCatalogRepository implements CustomerCatalogRepository {
  SupabaseCustomerCatalogRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Kitchen>> fetchKitchensWithCoordinates() async {
    try {
      final rows = await _client
          .from('kitchens')
          .select(
            'id,owner_id,name,address,latitude,longitude,image_path,is_active',
          )
          .eq('is_active', true)
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);
      return rows.map(Kitchen.fromMap).toList(growable: false);
    } on PostgrestException catch (error) {
      throw CustomerCatalogException(error.message);
    }
  }

  @override
  Future<Map<String, KitchenImageReference>> fetchRepresentativeImages() async {
    try {
      final kitchenRows = await _client
          .from('kitchens')
          .select('id,image_path')
          .eq('is_active', true)
          .not('image_path', 'is', null);
      final images = <String, KitchenImageReference>{};
      for (final row in kitchenRows) {
        final path = _optionalText(row['image_path']);
        if (path != null) {
          images[row['id'] as String] = KitchenImageReference(
            path: path,
            bucket: KitchenImageBucket.kitchen,
          );
        }
      }

      final rows = await _client
          .from('menu_items')
          .select('kitchen_id,image_path,image_url,created_at')
          .eq('is_available', true)
          .order('created_at', ascending: false);
      for (final row in rows) {
        final kitchenId = row['kitchen_id'] as String;
        if (images.containsKey(kitchenId)) continue;
        final path = _optionalText(row['image_path']);
        final url = _optionalText(row['image_url']);
        if (path != null || url != null) {
          images[kitchenId] = KitchenImageReference(path: path, url: url);
        }
      }
      return images;
    } on PostgrestException catch (error) {
      throw CustomerCatalogException(error.message);
    }
  }

  @override
  Future<List<MenuItem>> fetchAvailableMenuItems(String kitchenId) async {
    try {
      final rows = await _client
          .from('menu_items')
          .select(
            'id,kitchen_id,name,description,price,is_available,'
            'image_path,image_url',
          )
          .eq('kitchen_id', kitchenId)
          .eq('is_available', true)
          .order('created_at');
      return rows.map(MenuItem.fromMap).toList(growable: false);
    } on PostgrestException catch (error) {
      throw CustomerCatalogException(error.message);
    }
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class CustomerCatalogException implements Exception {
  const CustomerCatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}
