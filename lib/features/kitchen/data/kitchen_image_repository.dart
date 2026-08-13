import 'package:supabase_flutter/supabase_flutter.dart';

import '../../menu/data/menu_image_repository.dart';

const kitchenImagesBucket = 'kitchen-images';

String kitchenImageObjectPath({
  required String ownerId,
  required String kitchenId,
  required String generatedFileName,
}) => '$ownerId/$kitchenId/$generatedFileName';

abstract interface class KitchenImageRepository {
  Future<String> upload({
    required String ownerId,
    required String kitchenId,
    required PickedMenuImage image,
  });

  Future<void> delete(String path);

  String publicUrl(String path);
}

class SupabaseKitchenImageRepository implements KitchenImageRepository {
  SupabaseKitchenImageRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<String> upload({
    required String ownerId,
    required String kitchenId,
    required PickedMenuImage image,
  }) async {
    final generatedName =
        '${DateTime.now().microsecondsSinceEpoch}.${image.extension}';
    final path = kitchenImageObjectPath(
      ownerId: ownerId,
      kitchenId: kitchenId,
      generatedFileName: generatedName,
    );
    try {
      await _client.storage
          .from(kitchenImagesBucket)
          .uploadBinary(
            path,
            image.bytes,
            fileOptions: FileOptions(contentType: image.contentType),
          );
      return path;
    } on StorageException catch (error) {
      throw KitchenImageRepositoryException(error.message);
    }
  }

  @override
  Future<void> delete(String path) async {
    try {
      await _client.storage.from(kitchenImagesBucket).remove([path]);
    } on StorageException catch (error) {
      throw KitchenImageRepositoryException(error.message);
    }
  }

  @override
  String publicUrl(String path) =>
      _client.storage.from(kitchenImagesBucket).getPublicUrl(path);
}

class KitchenImageRepositoryException implements Exception {
  const KitchenImageRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
