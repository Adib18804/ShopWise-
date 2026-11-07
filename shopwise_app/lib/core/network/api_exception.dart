/// Custom exceptions for API errors
class ApiException implements Exception {

  ApiException({
    required this.message,
    this.statusCode,
    this.errorData,
  });
  final String message;
  final int? statusCode;
  final dynamic errorData;

  @override
  String toString() => 'ApiException: $message (Status: $statusCode)';
}

class NetworkException extends ApiException {
  NetworkException({super.message = 'No internet connection'});
}

class TimeoutException extends ApiException {
  TimeoutException({super.message = 'Request timeout'});
}

class UnauthorizedException extends ApiException {
  UnauthorizedException({super.message = 'Unauthorized'})
      : super(statusCode: 401);
}

class NotFoundException extends ApiException {
  NotFoundException({super.message = 'Resource not found'})
      : super(statusCode: 404);
}

class ServerException extends ApiException {
  ServerException({super.message = 'Internal server error'})
      : super(statusCode: 500);
}

class ValidationException extends ApiException {

  ValidationException({
    super.message = 'Validation failed',
    this.errors,
  }) : super(statusCode: 422);
  final List<ValidationError>? errors;
}

class ValidationError {

  ValidationError({
    required this.field,
    required this.message,
  });

  factory ValidationError.fromJson(Map<String, dynamic> json) => ValidationError(
      field: json['field'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  final String field;
  final String message;
}
