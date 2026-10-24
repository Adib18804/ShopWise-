import 'package:dio/dio.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_exception.dart';
import '../core/storage/secure_storage.dart';
import '../models/api_response_model.dart';
import '../models/daily_report_model.dart';

class ReportsRepository {
  final Dio _dio;
  final SecureStorage _secureStorage;

  ReportsRepository({Dio? dio, SecureStorage? secureStorage})
      : _dio = dio ?? Dio(),
        _secureStorage = secureStorage ?? SecureStorage.instance {
    _dio.options.baseUrl = ApiConstants.baseUrl;
    _dio.options.connectTimeout = ApiConstants.connectTimeout;
    _dio.options.receiveTimeout = ApiConstants.receiveTimeout;
    _dio.options.headers['Content-Type'] = 'application/json';
  }

  Future<DailyReportModel> getDailySummary() async {
    try {
      final token = await _secureStorage.getToken();
      if (token == null || token.isEmpty) {
        throw ApiException(
            message:
                '\u0986\u0997\u09c7 \u09b2\u0997\u0987\u09a8 \u0995\u09b0\u09c1\u09a8');
      }
      final response = await _dio.get<dynamic>(
        ApiConstants.reportDailySummary,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final envelope = ApiResponse<Map<String, dynamic>>.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json,
      );
      final data = envelope.data;
      if (response.statusCode != 200 || data == null) {
        throw ApiException(
            message: envelope.message, statusCode: response.statusCode);
      }
      return DailyReportModel.fromJson(data);
    } on DioException catch (error) {
      final body = error.response?.data;
      if (body is Map<String, dynamic>) {
        throw ApiException(
          message: body['message'] as String? ??
              error.message ??
              '\u09b0\u09bf\u09aa\u09cb\u09b0\u09cd\u099f \u09b2\u09cb\u09a1 \u0995\u09b0\u09be \u09af\u09be\u09df\u09a8\u09bf',
          statusCode: error.response?.statusCode,
        );
      }
      throw ApiException(
          message: error.message ??
              '\u09a8\u09c7\u099f\u0993\u09df\u09be\u09b0\u09cd\u0995 \u09b8\u09ae\u09b8\u09cd\u09af\u09be');
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(message: error.toString());
    }
  }
}
