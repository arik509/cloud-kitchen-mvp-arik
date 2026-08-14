import 'package:cloud_kitchen_mvp/core/location/location_models.dart';
import 'package:cloud_kitchen_mvp/core/location/location_picker_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

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

  test('invalid saved coordinates fall back to current location', () async {
    final result = await resolveInitialMapLocation(
      savedLatitude: 100,
      savedLongitude: 200,
      currentLocation: () async =>
          const GeoCoordinates(latitude: 23.8, longitude: 90.4),
    );
    expect(result.latitude, 23.8);
    expect(result.longitude, 90.4);
  });

  testWidgets('map picker confirms the current-location fallback', (
    tester,
  ) async {
    GeoCoordinates? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              selected = await Navigator.push<GeoCoordinates>(
                context,
                MaterialPageRoute(
                  builder: (_) => LocationPickerPage(
                    initialLocation: defaultMapLocation,
                    currentLocation: () async =>
                        const GeoCoordinates(latitude: 23.75, longitude: 90.35),
                  ),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-use-current-location')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('confirm-map-location')));
    await tester.pumpAndSettle();
    expect(selected!.latitude, 23.75);
    expect(selected!.longitude, 90.35);
  });
}
