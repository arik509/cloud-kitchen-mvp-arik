import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'location_models.dart';

class LocationMapMarker {
  const LocationMapMarker({
    required this.id,
    required this.label,
    required this.coordinates,
    required this.color,
    required this.icon,
  });

  final String id;
  final String label;
  final GeoCoordinates coordinates;
  final Color color;
  final IconData icon;
}

class LocationMapView extends StatefulWidget {
  const LocationMapView({
    required this.markers,
    this.initialCenter,
    this.onTap,
    this.controller,
    this.fitMarkers = true,
    this.initialZoom = 15,
    this.interactive = true,
    super.key,
  });

  final List<LocationMapMarker> markers;
  final GeoCoordinates? initialCenter;
  final void Function(GeoCoordinates coordinates)? onTap;
  final MapController? controller;
  final bool fitMarkers;
  final double initialZoom;
  final bool interactive;

  @override
  State<LocationMapView> createState() => _LocationMapViewState();
}

class _LocationMapViewState extends State<LocationMapView> {
  bool _ready = false;

  @override
  Widget build(BuildContext context) {
    final validMarkers = widget.markers
        .where((marker) => marker.coordinates.isValid)
        .toList(growable: false);
    final fallback = widget.initialCenter?.isValid == true
        ? widget.initialCenter!
        : validMarkers.isNotEmpty
        ? validMarkers.first.coordinates
        : const GeoCoordinates(latitude: 23.8103, longitude: 90.4125);
    final points = validMarkers
        .map(
          (marker) =>
              LatLng(marker.coordinates.latitude, marker.coordinates.longitude),
        )
        .toList(growable: false);

    return Stack(
      children: [
        FlutterMap(
          key: const Key('location-map'),
          mapController: widget.controller,
          options: MapOptions(
            initialCenter: LatLng(fallback.latitude, fallback.longitude),
            initialZoom: widget.initialZoom,
            initialCameraFit: widget.fitMarkers && points.isNotEmpty
                ? CameraFit.coordinates(
                    coordinates: points,
                    padding: const EdgeInsets.all(48),
                    maxZoom: 15,
                  )
                : null,
            interactionOptions: InteractionOptions(
              flags: widget.interactive
                  ? InteractiveFlag.all
                  : InteractiveFlag.none,
            ),
            onMapReady: () {
              if (mounted) setState(() => _ready = true);
            },
            onTap: widget.onTap == null
                ? null
                : (_, point) => widget.onTap!(
                    GeoCoordinates(
                      latitude: point.latitude,
                      longitude: point.longitude,
                    ),
                  ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.cloudkitchen.cloud_kitchen_mvp',
              maxZoom: 19,
            ),
            MarkerLayer(
              markers: [
                for (final marker in validMarkers)
                  Marker(
                    point: LatLng(
                      marker.coordinates.latitude,
                      marker.coordinates.longitude,
                    ),
                    width: 104,
                    height: 68,
                    alignment: Alignment.topCenter,
                    child: Semantics(
                      label: '${marker.label} map marker',
                      child: Column(
                        key: Key('map-marker-${marker.id}'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: marker.color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              marker.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Icon(marker.icon, color: marker.color, size: 36),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if (!_ready)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x33ffffff),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}
