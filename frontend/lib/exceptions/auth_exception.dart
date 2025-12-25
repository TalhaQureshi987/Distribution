class AuthException implements Exception {
  final String message;
  final int statusCode;
  final String responseBody;

  AuthException(this.message, this.statusCode, this.responseBody);

  @override
  String toString() => 'AuthException: $message (Status: $statusCode)';
}
