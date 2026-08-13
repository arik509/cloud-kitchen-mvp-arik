import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/customer_location.dart';

abstract interface class CustomerLocationService {
  Future<CustomerLocation> determineLocation();

  Future<bool> openLocationSettings();
}

class GeolocatorCustomerLocationService implements CustomerLocationService {
  const GeolocatorCustomerLocationService();

  @override
  Future<CustomerLocation> determineLocation() async {
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
          'Location permission was denied. Allow it to find nearby kitchens.',
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
      return CustomerLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on LocationException {
      rethrow;
    } on TimeoutException {
      throw const LocationException(
        LocationFailureCode.unavailable,
        'Your location request timed out. Check location access and retry.',
      );
    } on LocationServiceDisabledException {
      throw const LocationException(
        LocationFailureCode.servicesDisabled,
        'Location services are turned off. Enable location and retry.',
      );
    } on PermissionDeniedException {
      throw const LocationException(
        LocationFailureCode.denied,
        'Location permission was denied. Allow it to find nearby kitchens.',
      );
    } catch (_) {
      throw const LocationException(
        LocationFailureCode.unavailable,
        'Your location is unavailable right now. Check your connection and retry.',
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
