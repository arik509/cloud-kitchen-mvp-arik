import 'dart:typed_data';

import 'package:cloud_kitchen_mvp/features/menu/application/menu_item_workflow.dart';
import 'package:cloud_kitchen_mvp/features/menu/data/menu_image_repository.dart';
import 'package:cloud_kitchen_mvp/features/menu/data/menu_repository.dart';
import 'package:cloud_kitchen_mvp/features/menu/domain/menu_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const original = MenuItem(
    id: 'item-1',
    kitchenId: 'kitchen-1',
    name: 'Meal',
    description: 'Original description',
    price: 100,
    isAvailable: true,
    imagePath: 'owner-1/kitchen-1/item-1/old.jpg',
  );
  const draft = MenuItemDraft(
    name: 'Meal',
    description: 'Updated',
    price: 120,
    isAvailable: true,
  );
  final image = PickedMenuImage(
    bytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
    fileName: 'new.jpg',
    contentType: 'image/jpeg',
    extension: 'jpg',
  );

  test('archives an item when hard delete is blocked by an order', () async {
    final menu = FakeMenuRepository(
      initialItem: original,
      deleteError: const MenuItemReferencedException(),
    );

    final outcome = await deleteMenuItemSafely(menu, original);

    expect(outcome, MenuDeleteOutcome.archived);
    expect(menu.updated.single.isAvailable, isFalse);
    expect(menu.updated.single.description, 'Original description');
  });

  test(
    'reports image upload failure after preserving the created item',
    () async {
      final menu = FakeMenuRepository(initialItem: original);
      final images = FakeMenuImageRepository(uploadError: Exception('offline'));
      final workflow = MenuItemWorkflow(
        menuRepository: menu,
        imageRepository: images,
      );

      await expectLater(
        workflow.create(
          ownerId: 'owner-1',
          kitchenId: 'kitchen-1',
          draft: draft,
          image: image,
        ),
        throwsA(isA<MenuItemCreatedWithoutImageException>()),
      );
      expect(menu.created, hasLength(1));
      expect(menu.updated, isEmpty);
      expect(images.deletedPaths, isEmpty);
    },
  );

  test('cleans a replacement upload after a database update failure', () async {
    final menu = FakeMenuRepository(
      initialItem: original,
      updateError: const MenuRepositoryException('database failed'),
    );
    final images = FakeMenuImageRepository(
      uploadedPath: 'owner-1/kitchen-1/item-1/new.jpg',
    );
    final workflow = MenuItemWorkflow(
      menuRepository: menu,
      imageRepository: images,
    );

    await expectLater(
      workflow.update(
        ownerId: 'owner-1',
        original: original,
        draft: draft,
        replacementImage: image,
      ),
      throwsA(isA<MenuRepositoryException>()),
    );
    expect(images.deletedPaths, ['owner-1/kitchen-1/item-1/new.jpg']);
  });
}

class FakeMenuRepository implements MenuRepository {
  FakeMenuRepository({
    required this.initialItem,
    this.deleteError,
    this.updateError,
  });

  final MenuItem initialItem;
  final Object? deleteError;
  final Object? updateError;
  final List<MenuItemDraft> created = [];
  final List<MenuItem> updated = [];

  @override
  Future<MenuItem> create(String kitchenId, MenuItemDraft draft) async {
    created.add(draft);
    return initialItem;
  }

  @override
  Future<void> delete(String menuItemId) async {
    if (deleteError != null) throw deleteError!;
  }

  @override
  Future<List<MenuItem>> fetchForKitchen(String kitchenId) async => [
    initialItem,
  ];

  @override
  Future<MenuItem> update(MenuItem item) async {
    if (updateError != null) throw updateError!;
    updated.add(item);
    return item;
  }
}

class FakeMenuImageRepository implements MenuImageRepository {
  FakeMenuImageRepository({
    this.uploadedPath = 'owner-1/kitchen-1/item-1/generated.jpg',
    this.uploadError,
  });

  final String uploadedPath;
  final Object? uploadError;
  final List<String> deletedPaths = [];

  @override
  Future<void> delete(String path) async => deletedPaths.add(path);

  @override
  String publicUrl(String path) => 'https://images.example/$path';

  @override
  Future<String> upload({
    required String ownerId,
    required String kitchenId,
    required String menuItemId,
    required PickedMenuImage image,
  }) async {
    if (uploadError != null) throw uploadError!;
    return uploadedPath;
  }
}
