import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'location_models.dart';

/// Provides device coordinates without coupling callers to a specific UI.
/// A future map picker can implement a separate coordinate source and return
/// the same [GeoCoordinates] value.
abstract interface class LocationService {
  Future<GeoCoordinates> determineLocation();

  Future<bool> openLocationSettings();
}

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<GeoCoordinates> determineLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationException(
          LocationFailureCode.servicesDisabled,
          'Location services are turned off. Enable location and retry.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const LocationException(
          LocationFailureCode.denied,
          'Location permission was denied. Allow it and retry.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationException(
          LocationFailureCode.permanentlyDenied,
          'Location permission is blocked. Enable it in browser or app settings.',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return GeoCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationException {
      rethrow;
    } on TimeoutException {
      throw const LocationException(
        LocationFailureCode.timeout,
        'The location request timed out. Check location access and retry.',
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        LocationFailureCode.servicesDisabled,
        'Location services are turned off. Enable location and retry.',
      );
    } on PermissionDeniedException {
      throw const LocationException(
        LocationFailureCode.denied,
        'Location permission was denied. Allow it and retry.',
      );
    } catch (_) {
      throw const LocationException(
        LocationFailureCode.unavailable,
        'Location is unavailable right now. Check your connection and retry.',
      );
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      if (await Geolocator.openAppSettings()) return true;
      return Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }
}
