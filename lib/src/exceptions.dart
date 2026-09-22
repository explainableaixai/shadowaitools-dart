class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.body});
  final String message;
  final int? statusCode;
  final String? body;
  @override String toString() => 'ApiException($statusCode): $message';
}
class AuthenticationException extends ApiException { AuthenticationException(super.message, {super.statusCode, super.body}); }
class RateLimitException extends ApiException { RateLimitException(super.message, {super.statusCode, super.body}); }
