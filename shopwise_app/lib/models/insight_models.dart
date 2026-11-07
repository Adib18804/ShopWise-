/// Rule-based "Smart Assistant" insight models.
///
/// Derived entirely on the client from Firestore data (products + batches +
/// recent invoices). They describe risks and opportunities — ShopWise surfaces
/// them so the shopkeeper can decide; it never acts autonomously.
library;

enum StockOutSeverity { outOfStock, critical, warning }
enum ExpirySeverity { expired, critical, warning, notice }

/// "Milk may run out in 3 days" style alert.
class StockOutAlert {

  const StockOutAlert({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.currentStock,
    required this.avgDailySales,
    required this.daysRemaining,
    required this.suggestedRestock,
    required this.severity,
  });
  final String productId;
  final String productName;
  final String unit;
  final double currentStock;
  final double avgDailySales;
  final int daysRemaining;
  final double suggestedRestock;
  final StockOutSeverity severity;
}

/// A batch that is expired or expiring soon.
class ExpiryAlert {

  const ExpiryAlert({
    required this.batchId,
    required this.productId,
    required this.productName,
    required this.daysUntilExpiry, required this.quantity, required this.purchasePrice, required this.valueAtRisk, required this.severity, this.batchNumber,
  });
  final String batchId;
  final String productId;
  final String productName;
  final String? batchNumber;
  final int daysUntilExpiry;
  final double quantity;
  final double purchasePrice;
  final double valueAtRisk;
  final ExpirySeverity severity;
}

/// A product with stock on hand but no sales in the last 30 days.
class DeadStockAlert {

  const DeadStockAlert({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.stockQuantity,
    required this.stockValue,
    this.lastSaleDate,
  });
  final String productId;
  final String productName;
  final String unit;
  final double stockQuantity;
  final double stockValue;
  final DateTime? lastSaleDate;
}

/// The complete Smart Assistant summary shown on the dashboard.
class SmartSummary {

  const SmartSummary({
    required this.stockOutAlerts,
    required this.expiryAlerts,
    required this.deadStockAlerts,
    required this.totalExpiryValueAtRisk,
    required this.expiredValue,
    required this.expiryCount7Days,
    required this.expiryCount14Days,
    required this.expiryCount30Days,
    required this.expiredCount,
    required this.totalProducts,
    required this.totalActiveProducts,
    required this.totalStockValue,
    required this.todaySalesAmount,
    required this.todayItemsSold,
    required this.todayEstimatedProfit,
    required this.generatedAt,
  });
  final List<StockOutAlert> stockOutAlerts;
  final List<ExpiryAlert> expiryAlerts;
  final List<DeadStockAlert> deadStockAlerts;

  /// Cost value at risk — batches expiring in the next 14 days.
  final double totalExpiryValueAtRisk;

  /// Cost value already lost to expired batches (purchase_price × quantity).
  final double expiredValue;

  final int expiryCount7Days;
  final int expiryCount14Days;
  final int expiryCount30Days;
  final int expiredCount;

  final int totalProducts;
  final int totalActiveProducts;
  final double totalStockValue;

  /// Today's gross sales and items sold.
  final double todaySalesAmount;
  final int todayItemsSold;

  /// Today's estimated profit = sales – COGS (batch avg purchase prices).
  final double todayEstimatedProfit;

  final DateTime generatedAt;

  bool get hasAlerts =>
      stockOutAlerts.isNotEmpty ||
      expiryAlerts.isNotEmpty ||
      deadStockAlerts.isNotEmpty;

  int get alertCount =>
      stockOutAlerts.length + expiryAlerts.length + deadStockAlerts.length;
}
