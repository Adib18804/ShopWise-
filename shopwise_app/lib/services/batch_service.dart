import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/storage/secure_storage.dart';
import '../models/batch_model.dart';
import '../models/api_response_model.dart';

class BatchService {
  final Dio _dio;
  final SecureStorage _secureStorage;

  BatchService({Dio? dio, SecureStorage? secureStorage})
      : _dio = dio ?? Dio(),
        _secureStorage = secureStorage ?? SecureStorage.instance {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  Future<Map<String, String>> _headers() async {
    final token = await _secureStorage.getToken();
    if (token == null) throw ApiException(message: 'No authentication token found');
    return {'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> _data(Response<dynamic> response) {
    final envelope = ApiResponse.fromJson(
      response.data as Map<String, dynamic>,
      (json) => json,
    );
    return envelope.data as Map<String, dynamic>;
  }

  ApiException _toApiException(Object error, String fallback) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        return ApiException(
          message: data['message'] as String? ?? fallback,
          statusCode: error.response?.statusCode,
        );
      }
      return ApiException(message: error.message ?? fallback, statusCode: error.response?.statusCode);
    }
    if (error is ApiException) return error;
    return ApiException(message: '$fallback: $error');
  }

  Future<Map<String, dynamic>> getBatches(int productId, {bool includeDepleted = false}) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConstants.productBatches(productId),
        options: Options(headers: await _headers()),
        queryParameters: {'include_depleted': includeDepleted},
      );
      return _data(response);
    } catch (error) {
      throw _toApiException(error, 'Failed to load batches');
    }
  }

  Future<BatchModel> addBatch({
    required int productId,
    String? batchNumber,
    required DateTime purchaseDate,
    DateTime? expiryDate,
    required double quantity,
    required double purchasePrice,
  }) async {
    try {
      final response = await _dio.post<dynamic>(
        ApiConstants.productBatches(productId),
        options: Options(headers: await _headers()),
        data: {
          if (batchNumber != null && batchNumber.trim().isNotEmpty)
            'batch_number': batchNumber.trim(),
          'purchase_date': _dateOnly(purchaseDate),
          'expiry_date': expiryDate == null ? null : _dateOnly(expiryDate),
          'quantity': quantity,
          'purchase_price': purchasePrice,
        },
      );
      return BatchModel.fromJson(_data(response)['batch'] as Map<String, dynamic>);
    } catch (error) {
      throw _toApiException(error, 'Failed to add stock batch');
    }
  }

  Future<BatchModel> getBatch(int batchId) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConstants.batchById(batchId), options: Options(headers: await _headers()),
      );
      return BatchModel.fromJson(_data(response)['batch'] as Map<String, dynamic>);
    } catch (error) {
      throw _toApiException(error, 'Failed to load batch');
    }
  }

  Future<BatchModel> updateBatch(int batchId, Map<String, dynamic> changes) async {
    try {
      final response = await _dio.put<dynamic>(
        ApiConstants.batchById(batchId),
        options: Options(headers: await _headers()),
        data: changes,
      );
      return BatchModel.fromJson(_data(response)['batch'] as Map<String, dynamic>);
    } catch (error) {
      throw _toApiException(error, 'Failed to update batch');
    }
  }

  Future<void> deactivateBatch(int batchId) async {
    try {
      await _dio.delete<dynamic>(
        ApiConstants.batchById(batchId), options: Options(headers: await _headers()),
      );
    } catch (error) {
      throw _toApiException(error, 'Failed to deactivate batch');
    }
  }

  Future<Map<String, dynamic>> getStockHistory(int productId) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConstants.productStockHistory(productId),
        options: Options(headers: await _headers()),
      );
      return _data(response);
    } catch (error) {
      throw _toApiException(error, 'Failed to load stock history');
    }
  }

  Future<Map<String, dynamic>> getFefoRecommendations(int productId) async {
    try {
      final response = await _dio.get<dynamic>(
        ApiConstants.productFefo(productId),
        options: Options(headers: await _headers()),
      );
      return _data(response);
    } catch (error) {
      throw _toApiException(error, 'Failed to load FEFO recommendations');
    }
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}