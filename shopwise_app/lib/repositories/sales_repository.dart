import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/storage/secure_storage.dart';
import '../models/api_response_model.dart';
import '../models/sale_model.dart';
import '../models/sale_request.dart';

class SalesRepository {
  final Dio _dio;
  final SecureStorage _secureStorage;

  SalesRepository({Dio? dio, SecureStorage? secureStorage})
      : _dio = dio ?? Dio(),
        _secureStorage = secureStorage ?? SecureStorage.instance {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = ApiConstants.connectTimeout;
    _dio.options.receiveTimeout = ApiConstants.receiveTimeout;
    _dio.options.sendTimeout = ApiConstants.sendTimeout;
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  Future<SaleModel> processSale(SaleRequest request) async {
    try {
      final token = await _secureStorage.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException(message: 'No authentication token found');
      }

      final response = await _dio.post<dynamic>(
        ApiConstants.sales,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
        data: request.toJson(),
      );
      final envelope = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json,
      );
      final data = envelope.data;
      if (response.statusCode != 201 && response.statusCode != 200 ||
          data == null) {
        throw ApiException(
          message: envelope.message.isNotEmpty
              ? envelope.message
              : '??????? ??????? ??? ??????',
          statusCode: response.statusCode,
        );
      }
      return SaleModel.fromJson(data);
    } catch (error) {
      if (error is DioException) {
        final body = error.response?.data;
        if (body is Map<String, dynamic>) {
          throw ApiException(
            message: body['message'] as String? ??
                error.message ??
                '??????? ??????? ??? ??????',
            statusCode: error.response?.statusCode,
            errorData: body['errors'],
          );
        }
        throw ApiException(
          message: error.message ?? '????????? ???? ?????????? ?????? ??????',
          statusCode: error.response?.statusCode,
        );
      }
      if (error is ApiException) rethrow;
      throw ApiException(message: error.toString());
    }
  }
}
