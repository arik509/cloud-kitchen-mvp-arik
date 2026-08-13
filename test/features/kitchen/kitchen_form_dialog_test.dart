import 'dart:typed_data';

import 'package:cloud_kitchen_mvp/core/location/location_models.dart';
import 'package:cloud_kitchen_mvp/core/location/location_service.dart';
import 'package:cloud_kitchen_mvp/features/kitchen/presentation/kitchen_form_dialog.dart';
import 'package:cloud_kitchen_mvp/features/menu/data/menu_image_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .views
        .first
        .physicalSize = const Size(
      900,
      1200,
    );
    TestWidgetsFlutterBinding
            .instance
            .platformDispatcher
            .views
            .first
            .devicePixelRatio =
        1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetDevicePixelRatio();
  });

  testWidgets('uses current location without exposing coordinates normally', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const FakeLocationService(
          result: GeoCoordinates(latitude: 23.81, longitude: 90.41),
        ),
      ),
    );

    expect(find.text('Latitude (optional)'), findsNothing);
    expect(find.text('Longitude (optional)'), findsNothing);
    final locationButton = find.byKey(const Key('use-current-location'));
    await tester.ensureVisible(locationButton);
    await tester.tap(locationButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-success')), findsOneWidget);
    expect(find.text('Location added successfully'), findsOneWidget);
  });

  for (final code in LocationFailureCode.values) {
    testWidgets('shows ${code.name} location failure and retry', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          FakeLocationService(
            error: LocationException(code, '${code.name} message'),
          ),
        ),
      );
      final locationButton = find.byKey(const Key('use-current-location'));
      await tester.ensureVisible(locationButton);
      await tester.tap(locationButton);
      await tester.pumpAndSettle();

      expect(find.byKey(Key('location-error-${code.name}')), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      if (code == LocationFailureCode.permanentlyDenied ||
          code == LocationFailureCode.servicesDisabled) {
        expect(find.text('Open settings'), findsOneWidget);
      }
    });
  }

  testWidgets('manual coordinates remain optional and validate ranges', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const FakeLocationService(
          result: GeoCoordinates(latitude: 0, longitude: 0),
        ),
      ),
    );
    await tester.enterText(
      find.byKey(const Key('kitchen-name-field')),
      'Kitchen',
    );
    await tester.enterText(
      find.byKey(const Key('kitchen-address-field')),
      'Address',
    );
    final manualSection = find.byKey(const Key('manual-location-section'));
    await tester.ensureVisible(manualSection);
    await tester.tap(manualSection);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('kitchen-latitude-field')),
      '90.1',
    );
    await tester.enterText(
      find.byKey(const Key('kitchen-longitude-field')),
      '-180.1',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(find.textContaining('between -90'), findsOneWidget);
    expect(find.textContaining('between -180'), findsOneWidget);
  });

  testWidgets('previews a validated selected kitchen image', (tester) async {
    final image = PickedMenuImage(
      bytes: Uint8List.fromList(_onePixelPng),
      fileName: 'kitchen.png',
      contentType: 'image/png',
      extension: 'png',
    );
    await tester.pumpWidget(
      _app(
        const FakeLocationService(
          result: GeoCoordinates(latitude: 0, longitude: 0),
        ),
        picker: FakeImagePicker(image),
      ),
    );

    await tester.tap(find.text('Choose kitchen image'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('selected-kitchen-image-preview')),
      findsOneWidget,
    );
  });
}

const _onePixelPng = <int>[
  137,
  80,
  78,
  71,
  13,
  10,
  26,
  10,
  0,
  0,
  0,
  13,
  73,
  72,
  68,
  82,
  0,
  0,
  0,
  1,
  0,
  0,
  0,
  1,
  8,
  6,
  0,
  0,
  0,
  31,
  21,
  196,
  137,
  0,
  0,
  0,
  13,
  73,
  68,
  65,
  84,
  8,
  215,
  99,
  248,
  207,
  192,
  240,
  31,
  0,
  5,
  0,
  1,
  255,
  137,
  153,
  61,
  29,
  0,
  0,
  0,
  0,
  73,
  69,
  78,
  68,
  174,
  66,
  96,
  130,
];

Widget _app(LocationService location, {MenuImagePicker? picker}) => MaterialApp(
  home: Scaffold(
    body: KitchenFormDialog(
      locationService: location,
      imagePicker: picker ?? const FakeImagePicker(null),
    ),
  ),
);

class FakeLocationService implements LocationService {
  const FakeLocationService({this.result, this.error});

  final GeoCoordinates? result;
  final LocationException? error;

  @override
  Future<GeoCoordinates> determineLocation() async {
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<bool> openLocationSettings() async => false;
}

class FakeImagePicker implements MenuImagePicker {
  const FakeImagePicker(this.image);

  final PickedMenuImage? image;

  @override
  Future<PickedMenuImage?> pick() async => image;
}
