class GeoCoordinates {
  const GeoCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

enum LocationFailureCode {
  denied,
  permanentlyDenied,
  servicesDisabled,
  unavailable,
  timeout,
}

class LocationException implements Exception {
  const LocationException(this.code, this.message);

  final LocationFailureCode code;
  final String message;

  @override
  String toString() => message;
}
