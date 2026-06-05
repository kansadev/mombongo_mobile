class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? details;

  ApiException(this.message, this.statusCode, {this.details});

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}
