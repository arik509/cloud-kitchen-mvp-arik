import 'package:cloud_kitchen_mvp/core/location/location_models.dart';
import 'package:cloud_kitchen_mvp/core/location/location_picker_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('map picker prefers saved coordinates', () async {
    final result = await resolveInitialMapLocation(
      savedLatitude: 23.7,
      savedLongitude: 90.4,
      currentLocation: () async =>
          const GeoCoordinates(latitude: 1, longitude: 2),
    );
    expect(result.latitude, 23.7);
    expect(result.longitude, 90.4);
  });

  test('map picker uses current location then safe fallback', () async {
    final current = await resolveInitialMapLocation(
      currentLocation: () async =>
          const GeoCoordinates(latitude: 22, longitude: 91),
    );
    expect(current.latitude, 22);
    final fallback = await resolveInitialMapLocation(
      currentLocation: () => Future.error(StateError('unavailable')),
    );
    expect(fallback.latitude, defaultMapLocation.latitude);
    expect(fallback.longitude, defaultMapLocation.longitude);
  });
}
