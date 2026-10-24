import 'package:flutter/foundation.dart';

/// API endpoint constants
class ApiConstants {
  ApiConstants._();

  // Override with --dart-define=SHOPWISE_API_BASE_URL=<backend URL> for a
  // physical device or deployment. Android emulators reach the host via
  // 10.0.2.2; web, desktop, and iOS simulator use localhost by default.
  static const String _configuredBaseUrl =
      String.fromEnvironment('SHOPWISE_API_BASE_URL');
  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000/api/v1';
    }
    return 'http://localhost:3000/api/v1';
  }

  // Timeout durations
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  // Authentication endpoints
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String getCurrentUser = '/auth/me';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // Shop endpoints
  static const String shop = '/shop';
  static const String createShop = '/shop';
  static const String getMyShop = '/shop';
  static const String checkShop = '/shop/check';
  static String shopById(int id) => '/shop/$id';

  // Category endpoints
  static const String categories = '/categories';
  static String categoryById(int id) => '/categories/$id';

  // Product endpoints
  static const String products = '/products';
  static String productById(int id) => '/products/$id';
  static String productBatches(int id) => '/products/$id/batches';
  static String productStockHistory(int id) => '/products/$id/stock-history';
  static String productFefo(int id) => '/products/$id/fefo';

  // Batch endpoints
  static String batchById(int id) => '/batches/$id';

  // Sales endpoints
  static const String sales = '/sales';
  static String saleById(int id) => '/sales/$id';

  // Dashboard endpoint
  static const String dashboardSummary = '/dashboard/summary';
  static const String reportDailySummary = '/reports/daily-summary';

  // Analysis endpoints
  static const String analysisExpiryRisk = '/analysis/expiry-risk';
  static const String analysisStockRisk = '/analysis/stock-risk';
  static const String analysisRestock = '/analysis/restock';
  static const String analysisSlowMoving = '/analysis/slow-moving';
  static const String analysisFEFO = '/analysis/fefo';
  static const String analysisProfit = '/analysis/profit';
  static const String analysisDailySummary = '/analysis/daily-summary';

  // Notification endpoints
  static const String notifications = '/notifications';
  static String notificationRead(int id) => '/notifications/$id/read';
  static const String notificationsReadAll = '/notifications/read-all';
}
