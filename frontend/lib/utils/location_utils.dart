// Centralized location and distance calculation utilities
import 'dart:math';

class LocationUtils {
  // Care Connect center coordinates (configurable)
  static const double centerLatitude = 24.8607;
  static const double centerLongitude = 67.0011;

  /// Calculate distance between two coordinates using Haversine formula
  /// Returns distance in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a =
        _sin(dLat / 2) * _sin(dLat / 2) +
        _cos(_degreesToRadians(lat1)) *
            _cos(_degreesToRadians(lat2)) *
            _sin(dLon / 2) *
            _sin(dLon / 2);

    final double c = 2 * _atan2(_sqrt(a), _sqrt(1 - a));

    return earthRadius * c;
  }

  /// Calculate distance from user location to Care Connect center
  static double calculateDistanceToCenter(double? userLat, double? userLng) {
    if (userLat == null || userLng == null) {
      return 0.0;
    }

    return calculateDistance(centerLatitude, centerLongitude, userLat, userLng);
  }

  /// Get Care Connect center coordinates
  static Map<String, double> getCenterCoordinates() {
    return {'latitude': centerLatitude, 'longitude': centerLongitude};
  }

  // Helper functions for mathematical operations
  static double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  static double _sin(double value) {
    return sin(value);
  }

  static double _cos(double value) {
    return cos(value);
  }

  static double _atan2(double y, double x) {
    return atan2(y, x);
  }

  static double _sqrt(double value) {
    return sqrt(value);
  }
}
