import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/storage/secure_storage.dart';
import '../models/category_model.dart';
import '../models/api_response_model.dart';

/// Category service
class CategoryService {
  final Dio _dio;
  final SecureStorage _secureStorage;

  CategoryService({
    Dio? dio,
    SecureStorage? secureStorage,
  })  : _dio = dio ?? Dio(),
        _secureStorage = secureStorage ?? SecureStorage.instance {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  /// Get authorization header
  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _secureStorage.getToken();
    if (token == null) {
      throw ApiException(message: 'No authentication token found');
    }
    return {'Authorization': 'Bearer $token'};
  }

  /// Create new category
  Future<CategoryModel> createCategory({
    required String name,
    String? description,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.post<dynamic>(
        ApiConstants.categories,
        options: Options(headers: headers),
        data: {
          'name': name,
          if (description != null) 'description': description,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final categoryData = apiResponse.data as Map<String, dynamic>;
        return CategoryModel.fromJson(
            categoryData['category'] as Map<String, dynamic>);
      }

      throw ApiException(
        message: 'Failed to create category',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message =
              data['message'] as String? ?? 'Failed to create category';
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
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
      );
    }
  }

  /// Get all categories
  Future<List<CategoryModel>> getCategories() async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.get<dynamic>(
        ApiConstants.categories,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final data = apiResponse.data as Map<String, dynamic>;
        final categories = data['categories'] as List;

        return categories
            .map((json) =>
                CategoryModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ApiException(
        message: 'Failed to get categories',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message =
              data['message'] as String? ?? 'Failed to get categories';
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
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
      );
    }
  }

  /// Get category by ID
  Future<CategoryModel> getCategoryById(int id) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.get<dynamic>(
        ApiConstants.categoryById(id),
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final categoryData = apiResponse.data as Map<String, dynamic>;
        return CategoryModel.fromJson(
            categoryData['category'] as Map<String, dynamic>);
      }

      throw ApiException(
        message: 'Failed to get category',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message =
              data['message'] as String? ?? 'Failed to get category';
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
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
      );
    }
  }

  /// Update category
  Future<CategoryModel> updateCategory({
    required int id,
    String? name,
    String? description,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (description != null) data['description'] = description;

      final response = await _dio.put<dynamic>(
        ApiConstants.categoryById(id),
        options: Options(headers: headers),
        data: data,
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final categoryData = apiResponse.data as Map<String, dynamic>;
        return CategoryModel.fromJson(
            categoryData['category'] as Map<String, dynamic>);
      }

      throw ApiException(
        message: 'Failed to update category',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message =
              data['message'] as String? ?? 'Failed to update category';
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
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
      );
    }
  }

  /// Delete category
  Future<void> deleteCategory(int id) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.delete<dynamic>(
        ApiConstants.categoryById(id),
        options: Options(headers: headers),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to delete category',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message =
              data['message'] as String? ?? 'Failed to delete category';
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
      if (e is ApiException) rethrow;
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
      );
    }
  }
}
