/// Generic API response model
class ApiResponse<T> {

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>)? fromJsonT,
  ) => ApiResponse<T>(
      success: json['success'] as bool,
      message: json['message'] as String,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'] as Map<String, dynamic>)
          : null,
      errors: json['errors'] != null
          ? (json['errors'] as List)
              .map((e) => ApiError.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  final bool success;
  final String message;
  final T? data;
  final List<ApiError>? errors;
}

/// API error model
class ApiError {

  ApiError({
    required this.field,
    required this.message,
  });

  factory ApiError.fromJson(Map<String, dynamic> json) => ApiError(
      field: json['field'] as String? ?? '',
      message: json['message'] as String,
    );
  final String field;
  final String message;
}
