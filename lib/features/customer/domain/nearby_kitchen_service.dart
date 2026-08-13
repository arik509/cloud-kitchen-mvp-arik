import 'dart:math' as math;

import '../../kitchen/domain/kitchen.dart';
import 'customer_location.dart';
import 'nearby_kitchen.dart';

const defaultNearbyKitchenRadiusKm = 10.0;

double haversineDistanceKm(CustomerLocation origin, CustomerLocation target) {
  const earthRadiusKm = 6371.0;
  final latitudeDelta = _radians(target.latitude - origin.latitude);
  final longitudeDelta = _radians(target.longitude - origin.longitude);
  final originLatitude = _radians(origin.latitude);
  final targetLatitude = _radians(target.latitude);
  final a =
      math.sin(latitudeDelta / 2) * math.sin(latitudeDelta / 2) +
      math.cos(originLatitude) *
          math.cos(targetLatitude) *
          math.sin(longitudeDelta / 2) *
          math.sin(longitudeDelta / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

List<NearbyKitchen> nearbyKitchens({
  required CustomerLocation origin,
  required List<Kitchen> kitchens,
  required Map<String, KitchenImageReference> representativeImages,
  double radiusKm = defaultNearbyKitchenRadiusKm,
}) {
  final result = <NearbyKitchen>[];
  for (final kitchen in kitchens) {
    final latitude = kitchen.latitude;
    final longitude = kitchen.longitude;
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      continue;
    }
    final distance = haversineDistanceKm(
      origin,
      CustomerLocation(latitude: latitude, longitude: longitude),
    );
    if (distance > radiusKm) continue;
    final image = representativeImages[kitchen.id];
    result.add(
      NearbyKitchen(
        kitchen: kitchen,
        distanceKm: distance,
        representativeImagePath: image?.path,
        representativeImageUrl: image?.url,
      ),
    );
  }
  result.sort((left, right) => left.distanceKm.compareTo(right.distanceKm));
  return List.unmodifiable(result);
}

double _radians(double degrees) => degrees * math.pi / 180;
