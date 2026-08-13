import 'dart:async';

import 'package:cloud_kitchen_mvp/features/customer/data/customer_catalog_repository.dart';
import 'package:cloud_kitchen_mvp/features/customer/domain/nearby_kitchen.dart';
import 'package:cloud_kitchen_mvp/features/customer/presentation/customer_menu_page.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/domain/kitchen.dart';
import 'package:cloud_kitchen_mvp/features/menu/data/menu_image_repository.dart';
import 'package:cloud_kitchen_mvp/features/menu/domain/menu_item.dart';
import 'package:cloud_kitchen_mvp/features/orders/data/order_repository.dart';
import 'package:cloud_kitchen_mvp/features/orders/domain/order_models.dart';
import 'package:cloud_kitchen_mvp/features/wallet/data/wallet_repository.dart';
import 'package:cloud_kitchen_mvp/features/wallet/domain/wallet_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows only available menu items and fallback images', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CustomerMenuPage(
          kitchen: kitchen,
          catalogRepository: FakeCatalog(),
          imageRepository: FakeImageRepository(),
          walletRepository: FakeWalletRepository(),
          orderRepository: FakeOrderRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Available'), findsOneWidget);
    expect(find.text('Unavailable'), findsNothing);
    expect(find.byIcon(Icons.no_food_outlined), findsOneWidget);
    expect(find.text('Order'), findsOneWidget);
  });

  testWidgets('shows menu loading then empty state', (tester) async {
    final items = Completer<List<MenuItem>>();
    await tester.pumpWidget(_app(FakeCatalog(itemsResult: items.future)));

    expect(find.byKey(const Key('customer-menu-loading')), findsOneWidget);
    items.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('customer-menu-empty')), findsOneWidget);
  });

  testWidgets('shows menu error and retries', (tester) async {
    final catalog = FakeCatalog(
      responses: [
        Future.delayed(
          Duration.zero,
          () => throw const CustomerCatalogException('network'),
        ),
        Future.value(const []),
      ],
    );
    await tester.pumpWidget(_app(catalog));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('customer-menu-error')), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(catalog.fetchCalls, 2);
    expect(find.byKey(const Key('customer-menu-empty')), findsOneWidget);
  });
}

const kitchen = Kitchen(
  id: 'kitchen-1',
  ownerId: 'owner-1',
  name: 'Kitchen',
  address: 'Address',
);

Widget _app(CustomerCatalogRepository catalog) => MaterialApp(
  home: CustomerMenuPage(
    kitchen: kitchen,
    catalogRepository: catalog,
    imageRepository: FakeImageRepository(),
    walletRepository: FakeWalletRepository(),
    orderRepository: FakeOrderRepository(),
  ),
);

class FakeCatalog implements CustomerCatalogRepository {
  FakeCatalog({this.itemsResult, this.responses = const []});

  final Future<List<MenuItem>>? itemsResult;
  final List<Future<List<MenuItem>>> responses;
  int fetchCalls = 0;

  @override
  Future<List<MenuItem>> fetchAvailableMenuItems(String kitchenId) {
    final index = fetchCalls++;
    if (responses.isNotEmpty) {
      return responses[index < responses.length ? index : responses.length - 1];
    }
    return itemsResult ??
        Future.value(const [
          MenuItem(
            id: 'available',
            kitchenId: 'kitchen-1',
            name: 'Available',
            price: 100,
            isAvailable: true,
          ),
        ]);
  }

  @override
  Future<List<Kitchen>> fetchKitchensWithCoordinates() async => const [];

  @override
  Future<Map<String, KitchenImageReference>>
  fetchRepresentativeImages() async => const {};
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
