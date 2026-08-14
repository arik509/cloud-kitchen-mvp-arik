import '../../menu/data/menu_image_repository.dart';
import '../data/kitchen_image_repository.dart';
import '../data/kitchen_repository.dart';
import '../domain/kitchen.dart';

class KitchenWorkflow {
  const KitchenWorkflow({
    required this.kitchenRepository,
    required this.imageRepository,
  });

  final KitchenRepository kitchenRepository;
  final KitchenImageRepository imageRepository;

  Future<Kitchen> create({
    required String ownerId,
    required KitchenDraft draft,
    PickedMenuImage? image,
  }) async {
    final created = await kitchenRepository.create(ownerId, draft);
    if (image == null) return created;

    final String newPath;
    try {
      newPath = await imageRepository.upload(
        ownerId: ownerId,
        kitchenId: created.id,
        image: image,
      );
    } catch (error) {
      throw KitchenCreatedWithoutImageException(created, error);
    }

    try {
      return await kitchenRepository.update(
        ownerId,
        created.copyWith(imagePath: newPath),
      );
    } catch (_) {
      await _deleteQuietly(newPath);
      rethrow;
    }
  }

  Future<Kitchen> update({
    required String ownerId,
    required Kitchen original,
    required KitchenDraft draft,
    PickedMenuImage? replacementImage,
  }) async {
    if (replacementImage == null) {
      return kitchenRepository.update(ownerId, draft.applyTo(original));
    }

    final newPath = await imageRepository.upload(
      ownerId: ownerId,
      kitchenId: original.id,
      image: replacementImage,
    );
    try {
      final updated = await kitchenRepository.update(
        ownerId,
        draft.applyTo(original, imagePath: newPath),
      );
      final oldPath = original.imagePath;
      if (oldPath != null && oldPath != newPath) {
        await _deleteQuietly(oldPath);
      }
      return updated;
    } catch (_) {
      await _deleteQuietly(newPath);
      rethrow;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      await imageRepository.delete(path);
    } catch (_) {
      // Cleanup is best-effort and must not hide the primary failure.
    }
  }
}

class KitchenCreatedWithoutImageException implements Exception {
  const KitchenCreatedWithoutImageException(this.kitchen, this.cause);

  final Kitchen kitchen;
  final Object cause;

  @override
  String toString() => 'The kitchen was saved, but its image upload failed.';
}
