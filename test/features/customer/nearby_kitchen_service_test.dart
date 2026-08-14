import 'package:cloud_kitchen_mvp/core/location/location_models.dart';
import 'package:cloud_kitchen_mvp/features/customer/domain/nearby_kitchen.dart';
import 'package:cloud_kitchen_mvp/features/customer/domain/nearby_kitchen_service.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/domain/kitchen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Haversine returns a realistic distance', () {
    const dhaka = GeoCoordinates(latitude: 23.8103, longitude: 90.4125);
    const nearby = GeoCoordinates(latitude: 23.8203, longitude: 90.4125);

    expect(haversineDistanceKm(dhaka, nearby), closeTo(1.11, 0.03));
  });

  test('filters by radius, rejects invalid coordinates, and sorts nearest', () {
    const origin = GeoCoordinates(latitude: 23.8103, longitude: 90.4125);
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
      Kitchen(
        id: 'inactive',
        ownerId: 'owner',
        name: 'Inactive',
        address: 'Inactive address',
        latitude: 23.811,
        longitude: 90.4125,
        isActive: false,
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

  test('uses the latest saved coordinates on each calculation', () {
    const origin = GeoCoordinates(latitude: 23.8103, longitude: 90.4125);
    const previous = Kitchen(
      id: 'kitchen',
      ownerId: 'owner',
      name: 'Kitchen',
      address: 'Address',
      latitude: 24,
      longitude: 90.4125,
    );
    final updated = previous.copyWith(latitude: 23.811, longitude: 90.4125);

    expect(
      nearbyKitchens(
        origin: origin,
        kitchens: const [previous],
        representativeImages: const {},
      ),
      isEmpty,
    );
    expect(
      nearbyKitchens(
        origin: origin,
        kitchens: [updated],
        representativeImages: const {},
      ).single.kitchen.id,
      'kitchen',
    );
  });
}
