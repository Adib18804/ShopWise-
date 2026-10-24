import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/storage/secure_storage.dart';
import '../models/shop_model.dart';
import '../models/api_response_model.dart';

/// Shop service
class ShopService {
  final Dio _dio;
  final SecureStorage _secureStorage;

  ShopService({
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

  /// Create new shop
  Future<ShopModel> createShop({
    required String shopName,
    required String address,
    required String phone,
    String currency = 'BDT',
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.post<dynamic>(
        ApiConstants.createShop,
        options: Options(headers: headers),
        data: {
          'shop_name': shopName,
          'address': address,
          'phone': phone,
          'currency': currency,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final shopData = apiResponse.data as Map<String, dynamic>;
        final refreshedToken = shopData['token'] as String?;
        if (refreshedToken != null && refreshedToken.isNotEmpty) {
          await _secureStorage.saveToken(refreshedToken);
        }
        return ShopModel.fromJson(shopData['shop'] as Map<String, dynamic>);
      }

      throw ApiException(
        message: 'Failed to create shop',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message = data['message'] as String? ?? 'Failed to create shop';
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

  /// Get user's shop
  Future<ShopModel> getMyShop() async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.get<dynamic>(
        ApiConstants.getMyShop,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final shopData = apiResponse.data as Map<String, dynamic>;
        return ShopModel.fromJson(shopData['shop'] as Map<String, dynamic>);
      }

      throw ApiException(
        message: 'Failed to get shop',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message = data['message'] as String? ?? 'Failed to get shop';
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

  /// Check if user has shop
  Future<bool> checkShop() async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.get<dynamic>(
        ApiConstants.checkShop,
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final data = apiResponse.data as Map<String, dynamic>;
        return data['hasShop'] as bool;
      }

      return false;
    } catch (e) {
      // If any error, assume no shop
      return false;
    }
  }

  /// Update shop
  Future<ShopModel> updateShop({
    required int shopId,
    String? shopName,
    String? address,
    String? phone,
    String? currency,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final data = <String, dynamic>{};
      if (shopName != null) data['shop_name'] = shopName;
      if (address != null) data['address'] = address;
      if (phone != null) data['phone'] = phone;
      if (currency != null) data['currency'] = currency;

      final response = await _dio.put<dynamic>(
        ApiConstants.shopById(shopId),
        options: Options(headers: headers),
        data: data,
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final shopData = apiResponse.data as Map<String, dynamic>;
        return ShopModel.fromJson(shopData['shop'] as Map<String, dynamic>);
      }

      throw ApiException(
        message: 'Failed to update shop',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message = data['message'] as String? ?? 'Failed to update shop';
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

  /// Delete shop
  Future<void> deleteShop(int shopId) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.delete<dynamic>(
        ApiConstants.shopById(shopId),
        options: Options(headers: headers),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to delete shop',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message = data['message'] as String? ?? 'Failed to delete shop';
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
