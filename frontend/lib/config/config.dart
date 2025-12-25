class AppConfig {
  // Base URLs
  static const String _devBaseUrl = 'http://localhost:3001';
  static const String _prodBaseUrl = 'https://your-production-domain.com';

  // Get base URL based on environment
  static String get baseUrl {
    const environment =
        String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
    return environment == 'production' ? _prodBaseUrl : _devBaseUrl;
  }

  // API endpoints
  static const String login = '/api/auth/login';
  static const String register = '/api/auth/register';
  static const String profile = '/api/auth/profile';

  // Platform-specific URLs (only used in development mode)
  static String getDevUrl(String? platform) {
    switch (platform) {
      case 'android':
        return 'http://10.0.2.2:3001'; // Android Emulator
      case 'ios':
        return 'http://127.0.0.1:3001'; // iOS Simulator
      case 'web':
        return 'http://localhost:3001'; // Web browser
      case 'physical_device':
        return 'https://5e1457c9976b.ngrok-free.app'; // Physical device (ngrok)
      default:
        return 'https://5e1457c9976b.ngrok-free.app'; // Default to ngrok
    }
  }

  // Ngrok-specific headers
  static Map<String, String> get _ngrokHeaders => {
        'ngrok-skip-browser-warning': 'true',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // Default headers
  static Map<String, String> get _defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  // Get headers based on URL
  static Map<String, String> getHeaders(String url) {
    return isNgrokUrl(url) ? _ngrokHeaders : _defaultHeaders;
  }

  // Check if URL is ngrok
  static bool isNgrokUrl(String url) {
    return url.contains('ngrok');
  }
}
