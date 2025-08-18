import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class LocationService {
  static const String baseUrl = '/api/location';

  /// Get current location
  static Future<Map<String, dynamic>> getCurrentLocation() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission permanently denied');
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String address = '';
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        address =
            '${place.street}, ${place.locality}, ${place.administrativeArea}';
      }

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp?.toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to get current location: $e');
    }
  }

  /// Get address from coordinates
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.administrativeArea}';
      }

      return 'Unknown location';
    } catch (e) {
      throw Exception('Failed to get address: $e');
    }
  }

  /// Get coordinates from address
  static Future<Map<String, double>> getCoordinatesFromAddress(
    String address,
  ) async {
    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isNotEmpty) {
        return {
          'latitude': locations.first.latitude,
          'longitude': locations.first.longitude,
        };
      }

      throw Exception('No coordinates found for address');
    } catch (e) {
      throw Exception('Failed to get coordinates: $e');
    }
  }

  /// Save user location to backend
  static Future<void> saveUserLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    try {
      final token = await _getToken();
      final response = await http.post(
        Uri.parse('${ApiService.base}$baseUrl/save'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to save location: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to save location: $e');
    }
  }

  /// Get nearby donations/requests
  static Future<Map<String, dynamic>> getNearbyItems({
    required double latitude,
    required double longitude,
    required double radius,
    String? type, // 'donations' or 'requests'
  }) async {
    try {
      final token = await _getToken();
      final queryParams = <String, String>{
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
        if (type != null) 'type': type,
      };

      final uri = Uri.parse(
        '${ApiService.base}$baseUrl/nearby',
      ).replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to get nearby items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to get nearby items: $e');
    }
  }

  /// Calculate distance between two points
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Get token from SharedPreferences
  static Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null || token.isEmpty) {
      throw Exception('No authentication token found');
    }
    return token;
  }
}
