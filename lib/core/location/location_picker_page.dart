import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'location_map_view.dart';
import 'location_models.dart';

const defaultMapLocation = GeoCoordinates(
  latitude: 23.8103,
  longitude: 90.4125,
);

Future<GeoCoordinates> resolveInitialMapLocation({
  double? savedLatitude,
  double? savedLongitude,
  required Future<GeoCoordinates> Function() currentLocation,
}) async {
  if (savedLatitude != null && savedLongitude != null) {
    final saved = GeoCoordinates(
      latitude: savedLatitude,
      longitude: savedLongitude,
    );
    if (saved.isValid) return saved;
  }
  try {
    final current = await currentLocation();
    return current.isValid ? current : defaultMapLocation;
  } catch (_) {
    return defaultMapLocation;
  }
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({
    required this.initialLocation,
    this.currentLocation,
    this.title = 'Choose location',
    this.instruction = 'Tap the map to move the marker.',
    super.key,
  });
  final GeoCoordinates initialLocation;
  final Future<GeoCoordinates> Function()? currentLocation;
  final String title;
  final String instruction;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late GeoCoordinates _selected;
  final MapController _controller = MapController();
  bool _locating = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLocation.isValid
        ? widget.initialLocation
        : defaultMapLocation;
  }

  Future<void> _useCurrentLocation() async {
    final currentLocation = widget.currentLocation;
    if (currentLocation == null || _locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final current = await currentLocation();
      if (!current.isValid) throw const FormatException();
      if (!mounted) return;
      setState(() => _selected = current);
      _controller.move(LatLng(current.latitude, current.longitude), 16);
    } catch (_) {
      if (mounted) {
        setState(
          () => _locationError =
              'Current location is unavailable. You can still choose a pin.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Stack(
      children: [
        LocationMapView(
          controller: _controller,
          initialCenter: _selected,
          fitMarkers: false,
          markers: [
            LocationMapMarker(
              id: 'selected',
              label: 'Selected',
              coordinates: _selected,
              color: Theme.of(context).colorScheme.primary,
              icon: Icons.location_pin,
            ),
          ],
          onTap: (coordinates) => setState(() {
            _selected = coordinates;
            _locationError = null;
          }),
        ),
        if (widget.currentLocation != null)
          Positioned(
            right: 12,
            top: 12,
            child: FloatingActionButton.small(
              key: const Key('map-use-current-location'),
              onPressed: _locating ? null : _useCurrentLocation,
              tooltip: 'Use current location',
              child: _locating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 12,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.instruction),
                  if (_locationError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _locationError!,
                      key: const Key('map-current-location-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('confirm-map-location'),
                      onPressed: () => Navigator.pop(context, _selected),
                      icon: const Icon(Icons.check),
                      label: const Text('Confirm Location'),
                    ),
                  ),
                  const Text(
                    'Map © OpenStreetMap contributors',
                    style: TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
