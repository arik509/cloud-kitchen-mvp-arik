import 'dart:typed_data';

import 'package:cloud_kitchen_mvp/features/kitchen/application/kitchen_workflow.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/data/kitchen_image_repository.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/data/kitchen_repository.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/domain/kitchen.dart';
import 'package:cloud_kitchen_mvp/features/menu/data/menu_image_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const original = Kitchen(
    id: 'kitchen-1',
    ownerId: 'owner-1',
    name: 'Kitchen',
    address: 'Address',
    latitude: 23.8,
    longitude: 90.4,
    imagePath: 'owner-1/kitchen-1/old.jpg',
  );
  const draft = KitchenDraft(
    name: 'Updated Kitchen',
    address: 'Updated Address',
    latitude: 23.81,
    longitude: 90.41,
    isActive: false,
  );
  final image = PickedMenuImage(
    bytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
    fileName: 'new.jpg',
    contentType: 'image/jpeg',
    extension: 'jpg',
  );

  test('uses an owner/kitchen/generated filename image path', () {
    expect(
      kitchenImageObjectPath(
        ownerId: 'owner-1',
        kitchenId: 'kitchen-1',
        generatedFileName: 'generated.webp',
      ),
      'owner-1/kitchen-1/generated.webp',
    );
  });

  test('an image-only copy preserves saved coordinates', () {
    final updated = original.copyWith(imagePath: 'new.jpg');

    expect(updated.latitude, 23.8);
    expect(updated.longitude, 90.4);
  });

  test('replaces image only after database update succeeds', () async {
    final kitchens = FakeKitchenRepository(original);
    final images = FakeKitchenImageRepository(
      uploadedPath: 'owner-1/kitchen-1/new.jpg',
    );
    final result =
        await KitchenWorkflow(
          kitchenRepository: kitchens,
          imageRepository: images,
        ).update(
          ownerId: 'owner-1',
          original: original,
          draft: draft,
          replacementImage: image,
        );

    expect(result.imagePath, 'owner-1/kitchen-1/new.jpg');
    expect(result.isActive, isFalse);
    expect(images.deletedPaths, ['owner-1/kitchen-1/old.jpg']);
    expect(kitchens.updateOwners, ['owner-1']);
  });

  test('cleans the new image when database update fails', () async {
    final kitchens = FakeKitchenRepository(
      original,
      updateError: const KitchenRepositoryException('database failed'),
    );
    final images = FakeKitchenImageRepository(
      uploadedPath: 'owner-1/kitchen-1/new.jpg',
    );

    await expectLater(
      KitchenWorkflow(
        kitchenRepository: kitchens,
        imageRepository: images,
      ).update(
        ownerId: 'owner-1',
        original: original,
        draft: draft,
        replacementImage: image,
      ),
      throwsA(isA<KitchenRepositoryException>()),
    );
    expect(images.deletedPaths, ['owner-1/kitchen-1/new.jpg']);
  });

  test('owner-scoped repository rejects cross-owner updates', () {
    expect(
      () => verifyKitchenOwnership('owner-2', original),
      throwsA(
        isA<KitchenRepositoryException>().having(
          (error) => error.message,
          'message',
          contains('only your own kitchen'),
        ),
      ),
    );
  });
}

class FakeKitchenRepository implements KitchenRepository {
  FakeKitchenRepository(this.kitchen, {this.updateError});

  final Kitchen kitchen;
  final Object? updateError;
  final List<String> updateOwners = [];

  @override
  Future<Kitchen> create(String ownerId, KitchenDraft draft) async => kitchen;

  @override
  Future<Kitchen?> fetchForOwner(String ownerId) async => kitchen;

  @override
  Future<Kitchen> update(String ownerId, Kitchen kitchen) async {
    updateOwners.add(ownerId);
    if (updateError != null) throw updateError!;
    return kitchen;
  }
}

class FakeKitchenImageRepository implements KitchenImageRepository {
  FakeKitchenImageRepository({required this.uploadedPath});

  final String uploadedPath;
  final List<String> deletedPaths = [];

  @override
  Future<void> delete(String path) async => deletedPaths.add(path);

  @override
  String publicUrl(String path) => 'https://images.example/$path';

  @override
  Future<String> upload({
    required String ownerId,
    required String kitchenId,
    required PickedMenuImage image,
  }) async => uploadedPath;
}
