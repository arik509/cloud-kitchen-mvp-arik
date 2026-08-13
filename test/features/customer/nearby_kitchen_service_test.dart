import 'package:cloud_kitchen_mvp/features/customer/domain/customer_location.dart';
import 'package:cloud_kitchen_mvp/features/customer/domain/nearby_kitchen.dart';
import 'package:cloud_kitchen_mvp/features/customer/domain/nearby_kitchen_service.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/domain/kitchen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Haversine returns a realistic distance', () {
    const dhaka = CustomerLocation(latitude: 23.8103, longitude: 90.4125);
    const nearby = CustomerLocation(latitude: 23.8203, longitude: 90.4125);

    expect(haversineDistanceKm(dhaka, nearby), closeTo(1.11, 0.03));
  });

  test('filters by radius, rejects invalid coordinates, and sorts nearest', () {
    const origin = CustomerLocation(latitude: 23.8103, longitude: 90.4125);
    const kitchens = [
      Kitchen(
        id: 'far',
        ownerId: 'owner',
        name: 'Far',
        address: 'Far address',
        latitude: 24.0,
        longitude: 90.4125,
      ),
      Kitchen(
        id: 'second',
        ownerId: 'owner',
        name: 'Second',
        address: 'Second address',
        latitude: 23.82,
        longitude: 90.4125,
      ),
      Kitchen(
        id: 'nearest',
        ownerId: 'owner',
        name: 'Nearest',
        address: 'Nearest address',
        latitude: 23.811,
        longitude: 90.4125,
      ),
      Kitchen(
        id: 'invalid',
        ownerId: 'owner',
        name: 'Invalid',
        address: 'Invalid address',
        latitude: 91,
        longitude: 90,
      ),
      Kitchen(
        id: 'missing',
        ownerId: 'owner',
        name: 'Missing',
        address: 'Missing address',
      ),
    ];

    final result = nearbyKitchens(
      origin: origin,
      kitchens: kitchens,
      representativeImages: const {
        'nearest': KitchenImageReference(path: 'owner/kitchen/item/a.jpg'),
      },
      radiusKm: 10,
    );

    expect(result.map((entry) => entry.kitchen.id), ['nearest', 'second']);
    expect(result.first.representativeImagePath, isNotNull);
  });
}
