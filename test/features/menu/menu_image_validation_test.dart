import 'dart:typed_data';

import 'package:cloud_kitchen_mvp/features/menu/data/menu_image_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the owner, kitchen, item, and generated filename path', () {
    expect(
      menuImageObjectPath(
        ownerId: 'owner-1',
        kitchenId: 'kitchen-1',
        menuItemId: 'item-1',
        generatedFileName: 'generated.webp',
      ),
      'owner-1/kitchen-1/item-1/generated.webp',
    );
  });
  test('accepts valid JPEG, PNG, and WebP images', () {
    final jpeg = MenuImageValidator.validate(
      bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
      fileName: 'meal.jpeg',
      contentType: 'image/jpeg',
    );
    final png = MenuImageValidator.validate(
      bytes: Uint8List.fromList([
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
      ]),
      fileName: 'meal.png',
      contentType: 'image/png',
    );
    final webp = MenuImageValidator.validate(
      bytes: Uint8List.fromList([
        0x52,
        0x49,
        0x46,
        0x46,
        0,
        0,
        0,
        0,
        0x57,
        0x45,
        0x42,
        0x50,
      ]),
      fileName: 'meal.webp',
      contentType: 'image/webp',
    );

    expect(jpeg.extension, 'jpg');
    expect(png.contentType, 'image/png');
    expect(webp.extension, 'webp');
  });

  test('rejects unsupported and mismatched image types', () {
    expect(
      () => MenuImageValidator.validate(
        bytes: Uint8List.fromList([1, 2, 3]),
        fileName: 'meal.gif',
        contentType: 'image/gif',
      ),
      throwsA(isA<MenuImageValidationException>()),
    );
    expect(
      () => MenuImageValidator.validate(
        bytes: Uint8List.fromList([0xff, 0xd8, 0xff]),
        fileName: 'meal.png',
        contentType: 'image/jpeg',
      ),
      throwsA(isA<MenuImageValidationException>()),
    );
  });

  test('rejects files over the configured size limit', () {
    expect(
      () => MenuImageValidator.validate(
        bytes: Uint8List.fromList([0xff, 0xd8, 0xff, 0x00]),
        fileName: 'large.jpg',
        maximumBytes: 3,
      ),
      throwsA(isA<MenuImageValidationException>()),
    );
  });
}
