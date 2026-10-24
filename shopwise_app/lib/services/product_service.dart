

import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/storage/secure_storage.dart';
import '../models/product_model.dart';
import '../models/api_response_model.dart';

/// Product service
class ProductService {
  final Dio _dio;
  final SecureStorage _secureStorage;

  ProductService({
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

  /// Create new product
  Future<ProductModel> createProduct({
    required int categoryId,
    required String name,
    String? sku,
    String? barcode,
    required String unit,
    required double sellingPrice,
    required double defaultPurchasePrice,
    double minimumStock = 0,
    int targetStockDays = 7,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.post<dynamic>(
        ApiConstants.products,
        options: Options(headers: headers),
        data: {
          'category_id': categoryId,
          'name': name,
          if (sku != null && sku.isNotEmpty) 'sku': sku,
          if (barcode != null && barcode.isNotEmpty) 'barcode': barcode,
          'unit': unit,
          'selling_price': sellingPrice,
          'default_purchase_price': defaultPurchasePrice,
          'minimum_stock': minimumStock,
          'target_stock_days': targetStockDays,
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final productData = apiResponse.data as Map<String, dynamic>;
        return ProductModel.fromJson(
            productData['product'] as Map<String, dynamic>);
      }

      throw ApiException(
        message: 'Failed to create product',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message =
              data['message'] as String? ?? 'Failed to create product';
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

  /// Get all products
  Future<List<ProductModel>> getProducts({
    String? search,
    int? categoryId,
    int? limit,
    int? offset,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['q'] = search;
      if (categoryId != null) queryParams['category_id'] = categoryId;
      if (limit != null) queryParams['limit'] = limit;
      if (offset != null) queryParams['offset'] = offset;

      final response = await _dio.get<dynamic>(
        ApiConstants.products,
        options: Options(headers: headers),
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final data = apiResponse.data as Map<String, dynamic>;
        final products = data['products'] as List;

        return products
            .map(
                (json) => ProductModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ApiException(
        message: 'Failed to get products',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message =
              data['message'] as String? ?? 'Failed to get products';
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

  /// Get product by ID
  Future<ProductModel> getProductById(int id) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.get<dynamic>(
        ApiConstants.productById(id),
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final productData = apiResponse.data as Map<String, dynamic>;
        return ProductModel.fromJson(
            productData['product'] as Map<String, dynamic>);
      }

      throw ApiException(
        message: 'Failed to get product',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message =
              data['message'] as String? ?? 'Failed to get product';
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

  /// Update product
  Future<ProductModel> updateProduct({
    required int id,
    int? categoryId,
    String? name,
    String? sku,
    String? barcode,
    String? unit,
    double? sellingPrice,
    double? defaultPurchasePrice,
    double? minimumStock,
    int? targetStockDays,
  }) async {
    try {
      final headers = await _getAuthHeaders();

      final data = <String, dynamic>{};
      if (categoryId != null) data['category_id'] = categoryId;
      if (name != null) data['name'] = name;
      if (sku != null) data['sku'] = sku;
      if (barcode != null) data['barcode'] = barcode;
      if (unit != null) data['unit'] = unit;
      if (sellingPrice != null) data['selling_price'] = sellingPrice;
      if (defaultPurchasePrice != null) data['default_purchase_price'] = defaultPurchasePrice;
      if (minimumStock != null) data['minimum_stock'] = minimumStock;
      if (targetStockDays != null) data['target_stock_days'] = targetStockDays;

      final response = await _dio.put<dynamic>(
        ApiConstants.productById(id),
        options: Options(headers: headers),
        data: data,
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final productData = apiResponse.data as Map<String, dynamic>;
        return ProductModel.fromJson(
            productData['product'] as Map<String, dynamic>);
      }

      throw ApiException(
        message: 'Failed to update product',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message =
              data['message'] as String? ?? 'Failed to update product';
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

  /// Delete product
  Future<void> deleteProduct(int id) async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.delete<dynamic>(
        ApiConstants.productById(id),
        options: Options(headers: headers),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          message: 'Failed to delete product',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message =
              data['message'] as String? ?? 'Failed to delete product';
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

  /// Get low stock products
  Future<List<ProductModel>> getLowStockProducts() async {
    try {
      final headers = await _getAuthHeaders();

      final response = await _dio.get<dynamic>(
        '${ApiConstants.products}/low-stock',
        options: Options(headers: headers),
      );

      if (response.statusCode == 200) {
        final apiResponse = ApiResponse.fromJson(
          response.data as Map<String, dynamic>,
          (json) => json,
        );

        final data = apiResponse.data as Map<String, dynamic>;
        final products = data['products'] as List;

        return products
            .map(
                (json) => ProductModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      throw ApiException(
        message: 'Failed to get low stock products',
        statusCode: response.statusCode,
      );
    } on DioException catch (e) {
      if (e.response != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic>) {
          final message = data['message'] as String? ??
              'Failed to get low stock products';
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
