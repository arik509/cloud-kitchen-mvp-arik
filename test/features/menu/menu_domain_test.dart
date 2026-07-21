import 'package:cloud_kitchen_mvp/features/menu/domain/menu_item.dart';
import 'package:cloud_kitchen_mvp/features/menu/domain/menu_validation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('menu validation requires a name and positive finite price', () {
    expect(MenuInputValidator.name('  '), 'Item name is required');
    expect(MenuInputValidator.price('0'), isNotNull);
    expect(MenuInputValidator.price('-2'), isNotNull);
    expect(MenuInputValidator.price('NaN'), isNotNull);
    expect(MenuInputValidator.price('12.50'), isNull);
  });

  test('maps database menu fields into a typed MenuItem', () {
    final item = MenuItem.fromMap({
      'id': 'item-1',
      'kitchen_id': 'kitchen-1',
      'name': 'Rice bowl',
      'description': '  ',
      'price': 149,
      'is_available': false,
      'image_path': 'owner/kitchen/item/image.webp',
      'image_url': 'https://legacy.example/image.webp',
    });

    expect(item.id, 'item-1');
    expect(item.price, 149.0);
    expect(item.description, isNull);
    expect(item.isAvailable, isFalse);
    expect(item.imagePath, 'owner/kitchen/item/image.webp');
  });

  test('omits image_path from updates until an image has been uploaded', () {
    const item = MenuItem(
      id: 'item-1',
      kitchenId: 'kitchen-1',
      name: 'Meal',
      price: 100,
      isAvailable: true,
    );

    expect(item.toUpdateMap(), isNot(contains('image_path')));
    expect(
      item.copyWith(imagePath: 'owner/kitchen/item/image.jpg').toUpdateMap(),
      containsPair('image_path', 'owner/kitchen/item/image.jpg'),
    );
  });
  test('draft mapping keeps description optional', () {
    const draft = MenuItemDraft(
      name: ' Soup ',
      description: ' ',
      price: 80,
      isAvailable: true,
    );

    expect(draft.toInsertMap('kitchen-1'), {
      'kitchen_id': 'kitchen-1',
      'name': 'Soup',
      'description': null,
      'price': 80.0,
      'is_available': true,
    });
  });
}
