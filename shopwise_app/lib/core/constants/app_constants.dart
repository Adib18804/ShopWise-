/// Application-wide constants
class AppConstants {
  AppConstants._();
  
  // App information
  static const String appName = 'ShopWise';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Smart Business Assistant for Small Grocery Shopkeepers';
  
  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;
  
  // Analysis periods (in days)
  static const int defaultAnalysisPeriod = 30;
  static const int expiryRiskWindow = 14;
  static const int slowMovingThreshold = 30;
  static const int defaultTargetStockDays = 7;
  
  // Validation
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 50;
  static const int minProductNameLength = 1;
  static const int maxProductNameLength = 200;
  static const int minShopNameLength = 2;
  static const int maxShopNameLength = 200;
  
  // Date formats
  static const String displayDateFormat = 'dd MMM yyyy';
  static const String apiDateFormat = 'yyyy-MM-dd';
  static const String displayDateTimeFormat = 'dd MMM yyyy, hh:mm a';
  
  // Storage keys
  static const String authTokenKey = 'auth_token';
  static const String userDataKey = 'user_data';
  static const String languageKey = 'language';
  static const String themeKey = 'theme';
  static const String fcmTokenKey = 'fcm_token';
  
  // Default values
  static const String defaultCurrency = 'BDT';
  static const String defaultLanguage = 'bn'; // Bangla
  static const String defaultUnit = 'piece';
  
  // Risk levels
  static const String riskCritical = 'CRITICAL';
  static const String riskHigh = 'HIGH';
  static const String riskMedium = 'MEDIUM';
  static const String riskWarning = 'WARNING';
  static const String riskLowStock = 'LOW_STOCK';
  static const String riskNormal = 'NORMAL';
  static const String riskExpired = 'EXPIRED';
  
  // Notification types
  static const String notifExpiryRisk = 'EXPIRY_RISK';
  static const String notifStockOut = 'STOCK_OUT';
  static const String notifRestock = 'RESTOCK';
  static const String notifSlowMoving = 'SLOW_MOVING';
  static const String notifDailySummary = 'DAILY_SUMMARY';
  static const String notifSystem = 'SYSTEM';
  
  // Transaction types
  static const String transactionPurchase = 'PURCHASE';
  static const String transactionSale = 'SALE';
  static const String transactionAdjustmentIn = 'ADJUSTMENT_IN';
  static const String transactionAdjustmentOut = 'ADJUSTMENT_OUT';
  static const String transactionReturn = 'RETURN';
  static const String transactionExpired = 'EXPIRED';
  static const String transactionDamaged = 'DAMAGED';
}
