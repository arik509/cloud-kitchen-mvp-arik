import '../data/menu_image_repository.dart';
import '../data/menu_repository.dart';
import '../domain/menu_item.dart';

class MenuItemWorkflow {
  const MenuItemWorkflow({
    required this.menuRepository,
    required this.imageRepository,
  });

  final MenuRepository menuRepository;
  final MenuImageRepository imageRepository;

  Future<MenuItem> create({
    required String ownerId,
    required String kitchenId,
    required MenuItemDraft draft,
    PickedMenuImage? image,
  }) async {
    final created = await menuRepository.create(kitchenId, draft);
    if (image == null) return created;

    final String path;
    try {
      path = await imageRepository.upload(
        ownerId: ownerId,
        kitchenId: kitchenId,
        menuItemId: created.id,
        image: image,
      );
    } catch (error) {
      throw MenuItemCreatedWithoutImageException(created, error);
    }

    try {
      return await menuRepository.update(
        draft.applyTo(
          created,
          imagePath: path,
          imageUrl: imageRepository.publicUrl(path),
        ),
      );
    } catch (error) {
      await _deleteQuietly(path);
      rethrow;
    }
  }

  Future<MenuItem> update({
    required String ownerId,
    required MenuItem original,
    required MenuItemDraft draft,
    PickedMenuImage? replacementImage,
  }) async {
    if (replacementImage == null) {
      return menuRepository.update(draft.applyTo(original));
    }

    final path = await imageRepository.upload(
      ownerId: ownerId,
      kitchenId: original.kitchenId,
      menuItemId: original.id,
      image: replacementImage,
    );
    try {
      final updated = await menuRepository.update(
        draft.applyTo(
          original,
          imagePath: path,
          imageUrl: imageRepository.publicUrl(path),
        ),
      );
      if (original.imagePath != null && original.imagePath != path) {
        await _deleteQuietly(original.imagePath!);
      }
      return updated;
    } catch (error) {
      await _deleteQuietly(path);
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

class MenuItemCreatedWithoutImageException implements Exception {
  const MenuItemCreatedWithoutImageException(this.item, this.cause);

  final MenuItem item;
  final Object cause;

  @override
  String toString() => 'The item was saved, but its image upload failed.';
}
