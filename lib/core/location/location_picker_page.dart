import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
    return GeoCoordinates(latitude: savedLatitude, longitude: savedLongitude);
  }
  try {
    return await currentLocation();
  } catch (_) {
    return defaultMapLocation;
  }
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({required this.initialLocation, super.key});
  final GeoCoordinates initialLocation;

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  late LatLng _selected;

  @override
  void initState() {
    super.initState();
    _selected = LatLng(
      widget.initialLocation.latitude,
      widget.initialLocation.longitude,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose kitchen location')),
    body: Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _selected,
            initialZoom: 15,
            onTap: (_, point) => setState(() => _selected = point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.cloudkitchen.cloud_kitchen_mvp',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _selected,
                  width: 52,
                  height: 52,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.redAccent,
                    size: 48,
                  ),
                ),
              ],
            ),
          ],
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
                  const Text('Tap the map to move the kitchen marker.'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('confirm-map-location'),
                      onPressed: () => Navigator.pop(
                        context,
                        GeoCoordinates(
                          latitude: _selected.latitude,
                          longitude: _selected.longitude,
                        ),
                      ),
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
