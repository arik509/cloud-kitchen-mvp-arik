import 'dart:async';

import 'package:cloud_kitchen_mvp/features/kitchen/data/kitchen_repository.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/data/kitchen_image_repository.dart';
import 'package:cloud_kitchen_mvp/core/location/location_models.dart';
import 'package:cloud_kitchen_mvp/core/location/location_service.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/domain/kitchen.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/presentation/kitchen_page.dart';
import 'package:cloud_kitchen_mvp/features/menu/data/menu_image_repository.dart';
import 'package:cloud_kitchen_mvp/features/menu/data/menu_repository.dart';
import 'package:cloud_kitchen_mvp/features/menu/domain/menu_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const kitchen = Kitchen(
    id: 'kitchen-1',
    ownerId: 'owner-1',
    name: 'Test Kitchen',
    address: 'Test Address',
  );

  testWidgets('shows a loading state while kitchen data is pending', (
    tester,
  ) async {
    final pending = Completer<Kitchen?>();
    await tester.pumpWidget(
      _testApp(
        kitchenRepository: FakeKitchenRepository(fetch: (_) => pending.future),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('kitchen-loading')), findsOneWidget);
    pending.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('shows an empty menu state for a kitchen without items', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        kitchenRepository: FakeKitchenRepository(fetch: (_) async => kitchen),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Test Kitchen'), findsOneWidget);
    expect(find.byKey(const Key('menu-empty')), findsOneWidget);
  });

  testWidgets('shows Set Up Your Kitchen when owner has no kitchen', (
    tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        kitchenRepository: FakeKitchenRepository(fetch: (_) async => null),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kitchen-setup-empty')), findsOneWidget);
    expect(find.text('Set Up Your Kitchen'), findsNWidgets(2));
  });

  testWidgets(
    'shows existing image, active status, and missing location prompt',
    (tester) async {
      const existing = Kitchen(
        id: 'kitchen-1',
        ownerId: 'owner-1',
        name: 'Existing Kitchen',
        address: 'Existing Address',
        imagePath: 'owner-1/kitchen-1/photo.jpg',
        isActive: false,
      );
      await tester.pumpWidget(
        _testApp(
          kitchenRepository: FakeKitchenRepository(
            fetch: (_) async => existing,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('kitchen-summary')), findsOneWidget);
      expect(find.text('Existing Kitchen'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.byKey(const Key('kitchen-location-missing')), findsOneWidget);
    },
  );

  testWidgets('shows an error state and retries the repository request', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      _testApp(
        kitchenRepository: FakeKitchenRepository(
          fetch: (_) async {
            attempts++;
            if (attempts == 1) {
              throw const KitchenRepositoryException('Kitchen unavailable');
            }
            return kitchen;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kitchen-error')), findsOneWidget);
    expect(find.text('Kitchen unavailable'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.byKey(const Key('menu-empty')), findsOneWidget);
  });
}

Widget _testApp({required KitchenRepository kitchenRepository}) => MaterialApp(
  home: Scaffold(
    body: KitchenPage(
      ownerId: 'owner-1',
      kitchenRepository: kitchenRepository,
      menuRepository: FakeMenuRepository(),
      imageRepository: FakeMenuImageRepository(),
      imagePicker: const FakeMenuImagePicker(),
      kitchenImageRepository: FakeKitchenImageRepository(),
      locationService: const FakeLocationService(),
    ),
  ),
);

class FakeKitchenRepository implements KitchenRepository {
  FakeKitchenRepository({required this.fetch});

  final Future<Kitchen?> Function(String ownerId) fetch;

  @override
  Future<Kitchen> create(String ownerId, KitchenDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<Kitchen?> fetchForOwner(String ownerId) => fetch(ownerId);

  @override
  Future<Kitchen> update(String ownerId, Kitchen kitchen) async => kitchen;
}

class FakeMenuRepository implements MenuRepository {
  @override
  Future<MenuItem> create(String kitchenId, MenuItemDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String menuItemId) async {}

  @override
  Future<List<MenuItem>> fetchForKitchen(String kitchenId) async => const [];

  @override
  Future<MenuItem> update(MenuItem item) async => item;
}

class FakeMenuImageRepository implements MenuImageRepository {
  @override
  Future<void> delete(String path) async {}

  @override
  String publicUrl(String path) => 'https://images.example/$path';

  @override
  Future<String> upload({
    required String ownerId,
    required String kitchenId,
    required String menuItemId,
    required PickedMenuImage image,
  }) {
    throw UnimplementedError();
  }
}

class FakeMenuImagePicker implements MenuImagePicker {
  const FakeMenuImagePicker();

  @override
  Future<PickedMenuImage?> pick() async => null;
}

class FakeKitchenImageRepository implements KitchenImageRepository {
  @override
  Future<void> delete(String path) async {}

  @override
  String publicUrl(String path) => 'https://kitchens.example/$path';

  @override
  Future<String> upload({
    required String ownerId,
    required String kitchenId,
    required PickedMenuImage image,
  }) => throw UnimplementedError();
}

class FakeLocationService implements LocationService {
  const FakeLocationService();

  @override
  Future<GeoCoordinates> determineLocation() async =>
      const GeoCoordinates(latitude: 23.81, longitude: 90.41);

  @override
  Future<bool> openLocationSettings() async => false;
}
