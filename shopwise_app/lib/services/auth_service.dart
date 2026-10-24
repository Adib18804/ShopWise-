import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/storage/secure_storage.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';
import '../models/api_response_model.dart';

/// Authentication service
class AuthService {
  final Dio _dio;
  final SecureStorage _secureStorage;

  AuthService({
    Dio? dio,
    SecureStorage? secureStorage,
  })  : _dio = dio ?? Dio(),
        _secureStorage = secureStorage ?? SecureStorage.instance {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  /// Register new user
  Future<AuthResponseModel> register({
    required String name,
    required String phone,
    required String email,
    required String password,
    String preferredLanguage = 'bn',
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.register,
        data: {
          'name': name,
          'phone': phone,
          'email': email,
          'password': password,
          'preferred_language': preferredLanguage,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final authResponse = AuthResponseModel.fromJson(
          apiResponse.data as Map<String, dynamic>,
        );

        // Save token
        await _secureStorage.saveToken(authResponse.token);

        return authResponse;
      }

      throw ApiException(
        message: 'Registration failed',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message = data['message'] as String? ?? 'Registration failed';
          final errors = data['errors'] as List?;
          
          String errorMessage = message;
          if (errors != null && errors.isNotEmpty) {
            final firstError = errors[0] as Map<String, dynamic>;
            errorMessage = firstError['message'] as String? ?? message;
          }
          
          throw ApiException(
            message: errorMessage,
            statusCode: e.response!.statusCode,
          );
        }
      }
      throw ApiException(
        message: e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
      );
    }
  }

  /// Login user
  Future<AuthResponseModel> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.login,
        data: {
          'identifier': identifier,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final authResponse = AuthResponseModel.fromJson(
          apiResponse.data as Map<String, dynamic>,
        );

        // Save token
        await _secureStorage.saveToken(authResponse.token);

        return authResponse;
      }

      throw ApiException(
        message: 'Login failed',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message = data['message'] as String? ?? 'Login failed';
          throw ApiException(
            message: message,
            statusCode: e.response!.statusCode,
          );
        }
      }
      throw ApiException(
        message: e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
      );
    }
  }

  /// Get current user
  Future<UserModel> getCurrentUser() async {
    try {
      final token = await _secureStorage.getToken();
      
      if (token == null) {
        throw ApiException(message: 'No authentication token found');
      }

      final response = await _dio.get<dynamic>(
        ApiConstants.getCurrentUser,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final userData = apiResponse.data as Map<String, dynamic>;
        return UserModel.fromJson(userData['user'] as Map<String, dynamic>);
      }

      throw ApiException(
        message: 'Failed to get user',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode == 401) {
        // Token expired or invalid
        await _secureStorage.deleteToken();
        throw ApiException(
          message: 'Session expired',
          statusCode: 401,
        );
      }
      
      throw ApiException(
        message: e.message ?? 'Network error',
        statusCode: e.response?.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
      );
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      final token = await _secureStorage.getToken();
      
      if (token != null) {
        try {
          await _dio.post<dynamic>(
            ApiConstants.logout,
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
              },
            ),
          );
        } catch (e) {
          // Ignore logout API errors
        }
      }

      // Always clear local token
      await _secureStorage.deleteToken();
    } catch (e) {
      // Always clear token even if API call fails
      await _secureStorage.deleteToken();
    }
  }

  /// Check if user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await _secureStorage.getToken();
    return token != null && token.isNotEmpty;
  }

  /// Get stored token
  Future<String?> getToken() async {
    return await _secureStorage.getToken();
  }
}
