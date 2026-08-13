import 'dart:async';

import 'package:cloud_kitchen_mvp/core/location/location_models.dart';
import 'package:cloud_kitchen_mvp/core/location/location_service.dart';
import 'package:cloud_kitchen_mvp/features/customer/data/customer_catalog_repository.dart';
import 'package:cloud_kitchen_mvp/features/customer/domain/nearby_kitchen.dart';
import 'package:cloud_kitchen_mvp/features/customer/presentation/customer_discovery_page.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/domain/kitchen.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/data/kitchen_image_repository.dart';
import 'package:cloud_kitchen_mvp/features/menu/data/menu_image_repository.dart';
import 'package:cloud_kitchen_mvp/features/menu/domain/menu_item.dart';
import 'package:cloud_kitchen_mvp/features/orders/data/order_repository.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:cloud_kitchen_mvp/features/wallet/data/wallet_repository.dart';
import 'package:cloud_kitchen_mvp/features/wallet/domain/wallet_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'shows loading then nearest kitchens with distance and image fallback',
    (tester) async {
      final location = Completer<GeoCoordinates>();
      await tester.pumpWidget(
        _app(
          locationService: FakeLocationService(result: location.future),
          catalog: FakeCatalog(kitchens: const [_kitchen]),
        ),
      );
      expect(find.byKey(const Key('discovery-loading')), findsOneWidget);

      location.complete(
        const GeoCoordinates(latitude: 23.8103, longitude: 90.4125),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nearby-kitchen-list')), findsOneWidget);
      expect(find.text('Test Kitchen'), findsOneWidget);
      expect(find.textContaining('km away'), findsOneWidget);
      expect(find.byIcon(Icons.no_food_outlined), findsOneWidget);
    },
  );

  testWidgets('shows empty state when no kitchen is inside radius', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        locationService: FakeLocationService(
          result: Future.value(const GeoCoordinates(latitude: 0, longitude: 0)),
        ),
        catalog: FakeCatalog(kitchens: const [_kitchen]),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('discovery-empty')), findsOneWidget);
  });

  for (final code in LocationFailureCode.values) {
    testWidgets('handles ${code.name} location state', (tester) async {
      await tester.pumpWidget(
        _app(
          locationService: FakeLocationService(
            result: Future.delayed(
              Duration.zero,
              () => throw LocationException(code, code.name),
            ),
          ),
          catalog: FakeCatalog(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(Key('location-${code.name}')), findsOneWidget);
    });
  }
}

const _kitchen = Kitchen(
  id: 'kitchen-1',
  ownerId: 'owner-1',
  name: 'Test Kitchen',
  address: 'Test Address',
  latitude: 23.811,
  longitude: 90.4125,
);

Widget _app({
  required LocationService locationService,
  required CustomerCatalogRepository catalog,
}) => MaterialApp(
  home: Scaffold(
    body: CustomerDiscoveryPage(
      locationService: locationService,
      catalogRepository: catalog,
      imageRepository: FakeImageRepository(),
      kitchenImageRepository: FakeKitchenImageRepository(),
      walletRepository: FakeWalletRepository(),
      orderRepository: FakeOrderRepository(),
    ),
  ),
);

class FakeLocationService implements LocationService {
  FakeLocationService({required this.result});

  final Future<GeoCoordinates> result;

  @override
  Future<GeoCoordinates> determineLocation() => result;

  @override
  Future<bool> openLocationSettings() async => false;
}

class FakeCatalog implements CustomerCatalogRepository {
  FakeCatalog({this.kitchens = const [], this.items = const []});

  final List<Kitchen> kitchens;
  final List<MenuItem> items;

  @override
  Future<List<Kitchen>> fetchKitchensWithCoordinates() async => kitchens;

  @override
  Future<Map<String, KitchenImageReference>>
  fetchRepresentativeImages() async => const {};

  @override
  Future<List<MenuItem>> fetchAvailableMenuItems(String kitchenId) async =>
      items.where((item) => item.isAvailable).toList();
}

class FakeImageRepository implements MenuImageRepository {
  @override
  Future<void> delete(String path) async {}

  @override
  String publicUrl(String path) => 'https://example.test/$path';

  @override
  Future<String> upload({
    required String ownerId,
    required String kitchenId,
    required String menuItemId,
    required PickedMenuImage image,
  }) async => 'path';
}

class FakeKitchenImageRepository implements KitchenImageRepository {
  @override
  Future<void> delete(String path) async {}

  @override
  String publicUrl(String path) => 'https://kitchens.example.test/$path';

  @override
  Future<String> upload({
    required String ownerId,
    required String kitchenId,
    required PickedMenuImage image,
  }) async => 'path';
}

class FakeWalletRepository implements WalletRepository {
  @override
  Future<AddDemoBalanceResult> addDemoBalance() => throw UnimplementedError();

  @override
  Future<WalletBalance> fetchCurrentBalance() async => const WalletBalance(0);
}

class FakeOrderRepository implements OrderRepository {
  @override
  Future<List<CustomerOrder>> fetchCurrentCustomerOrders() async => const [];

  @override
  Future<PlaceOrderResult> placeOrder(PlaceOrderRequest request) =>
      throw UnimplementedError();
}
