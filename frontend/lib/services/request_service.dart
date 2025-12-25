import 'api_service.dart';
import 'auth_service.dart';

class RequestService {
  /// Get request dashboard statistics
  static Future<Map<String, dynamic>> getRequestDashboardStats() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/requests/dashboard-stats',
        token: token,
      );
      return response['stats'] ?? {};
    } on AuthException catch (e) {
      print(
        '⚠️ Authentication error in getRequestDashboardStats: ${e.message}',
      );
      // Don't throw - return empty stats to prevent dashboard crash
      return {};
    } catch (e) {
      print('❌ Error fetching request dashboard stats: $e');
      // Return empty stats instead of throwing to prevent dashboard crash
      return {};
    }
  }

  /// Get user's requests
  static Future<List<Map<String, dynamic>>> getUserRequests() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/requests/my-requests',
        token: token,
      );
      return List<Map<String, dynamic>>.from(response['requests'] ?? []);
    } catch (e) {
      print('Error fetching user requests: $e');
      return [];
    }
  }

  /// Create a new request
  static Future<Map<String, dynamic>> createRequest(
    Map<String, dynamic> requestData,
  ) async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.postJson(
        '/api/requests',
        body: requestData,
        token: token,
      );
      return response;
    } catch (e) {
      print('Error creating request: $e');
      rethrow;
    }
  }

  /// Get request by ID
  static Future<Map<String, dynamic>> getRequestById(String requestId) async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/requests/$requestId',
        token: token,
      );
      return response['request'] ?? {};
    } catch (e) {
      print('Error fetching request by ID: $e');
      return {};
    }
  }

  /// Get available requests (for volunteers/delivery personnel)
  static Future<List<Map<String, dynamic>>> getAvailableRequests({
    String? foodType,
    double? latitude,
    double? longitude,
    double? radius,
    bool? isUrgent,
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await AuthService.getValidToken();

      // Build query parameters
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };

      if (foodType != null) queryParams['foodType'] = foodType;
      if (latitude != null) queryParams['latitude'] = latitude.toString();
      if (longitude != null) queryParams['longitude'] = longitude.toString();
      if (radius != null) queryParams['radius'] = radius.toString();
      if (isUrgent != null) queryParams['isUrgent'] = isUrgent.toString();
      if (status != null) queryParams['status'] = status;

      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await ApiService.getJson(
        '/api/requests?$queryString',
        token: token,
      );

      return List<Map<String, dynamic>>.from(response['requests'] ?? []);
    } catch (e) {
      print('Error fetching available requests: $e');
      return [];
    }
  }

  /// Get requests by delivery option
  static Future<List<Map<String, dynamic>>> getRequestsByDeliveryOption(
    String deliveryOption,
  ) async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/requests/delivery-option/$deliveryOption',
        token: token,
      );
      return List<Map<String, dynamic>>.from(response['requests'] ?? []);
    } catch (e) {
      print('Error fetching requests by delivery option: $e');
      return [];
    }
  }

  /// Get urgent requests
  static Future<List<Map<String, dynamic>>> getUrgentRequests() async {
    try {
      final token = await AuthService.getValidToken();
      final response = await ApiService.getJson(
        '/api/requests/urgent',
        token: token,
      );
      return List<Map<String, dynamic>>.from(response['requests'] ?? []);
    } catch (e) {
      print('Error fetching urgent requests: $e');
      return [];
    }
  }

  /// Calculate service cost for a request
  static int calculateServiceCost(int requestCount) {
    const int SERVICE_COST_PER_REQUEST = 100;
    return requestCount * SERVICE_COST_PER_REQUEST;
  }

  /// Get service cost breakdown
  static Map<String, int> getServiceCostBreakdown({
    required int totalRequests,
    required int verifiedRequests,
    required int pendingRequests,
  }) {
    const int SERVICE_COST_PER_REQUEST = 100;

    return {
      'totalServiceCost': totalRequests * SERVICE_COST_PER_REQUEST,
      'paidServiceCost': verifiedRequests * SERVICE_COST_PER_REQUEST,
      'pendingServiceCost': pendingRequests * SERVICE_COST_PER_REQUEST,
      'serviceCostPerRequest': SERVICE_COST_PER_REQUEST,
    };
  }
}
