/// Rule-based "Smart Assistant" insight models.
///
/// These are derived entirely on the client from Firestore data
/// (products + batches + recent invoices). They describe *risks and
/// opportunities* for the shopkeeper — ShopWise never acts on them; it only
/// surfaces them so the shopkeeper can decide.

/// How urgent a stock-out risk is.
enum StockOutSeverity {
  /// Product is already out of stock.
  outOfStock,
  /// At the current sales pace, stock runs out in < 2 days.
  critical,
  /// At the current sales pace, stock runs out in 2–4 days.
  warning,
}

/// How urgent an expiry risk is.
enum ExpirySeverity {
  /// Batch is already past its expiry date.
  expired,
  /// Expires within 7 days.
  critical,
  /// Expires within 8–14 days.
  warning,
  /// Expires within 15–30 days (informational).
  notice,
}

/// "Milk may run out in 3 days" style alert.
///
/// Derived from: `daysRemaining = currentStock / avgDailySales` where
/// `avgDailySales` is the average daily quantity sold over the last 7 days.
/// An alert is raised when `daysRemaining < 5` (or the product is already
/// out of stock).
class StockOutAlert {
  final String productId;
  final String productName;
  final String unit;
  final double currentStock;
  final double avgDailySales;
  /// Whole days of stock left at the current pace. `0` when already out of
  /// stock. Always non-null for [StockOutAlert].
  final int daysRemaining;
  /// Suggested quantity to restock so stock covers `targetStockDays` again.
  /// Falls back to the reorder level when there is no sales velocity.
  final double suggestedRestock;
  final StockOutSeverity severity;

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
}

/// A batch that is expired or expiring soon, with the cost value still at risk.
class ExpiryAlert {
  final String batchId;
  final String productId;
  final String productName;
  final String? batchNumber;
  /// Days until expiry. Negative means already expired.
  final int daysUntilExpiry;
  final double quantity;
  final double purchasePrice;
  /// `purchasePrice * quantity` — the cost value tied up in this batch.
  final double valueAtRisk;
  final ExpirySeverity severity;

  const ExpiryAlert({
    required this.batchId,
    required this.productId,
    required this.productName,
    this.batchNumber,
    required this.daysUntilExpiry,
    required this.quantity,
    required this.purchasePrice,
    required this.valueAtRisk,
    required this.severity,
  });
}

/// A product with stock on hand but no sales in the last 30 days.
///
/// To avoid flagging brand-new products, a product must have existed for at
/// least 30 days (`createdAt` age >= 30) before it can be considered dead stock.
class DeadStockAlert {
  final String productId;
  final String productName;
  final String unit;
  final double stockQuantity;
  /// Estimated cost value of the stock on hand.
  final double stockValue;
  /// Last sale date within the analysed window, or `null` if none recorded.
  final DateTime? lastSaleDate;

  const DeadStockAlert({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.stockQuantity,
    required this.stockValue,
    this.lastSaleDate,
  });
}

/// The full Smart Assistant summary shown on the dashboard.
class SmartSummary {
  /// Stock-out risks, sorted by soonest run-out first.
  final List<StockOutAlert> stockOutAlerts;
  /// Expired + expiring batches (<= 30 days), sorted by soonest expiry first.
  final List<ExpiryAlert> expiryAlerts;
  /// Dead stock, sorted by highest tied-up value first.
  final List<DeadStockAlert> deadStockAlerts;

  /// Cost value at risk across batches expiring in the next 14 days (the rule
  /// threshold). Excludes already-expired batches.
  final double totalExpiryValueAtRisk;
  /// Cost value already lost to expired batches.
  final double expiredValue;

  final int expiryCount7Days;
  final int expiryCount14Days;
  final int expiryCount30Days;
  final int expiredCount;

  final int totalProducts;
  final int totalActiveProducts;
  /// Total cost value of all stock on hand.
  final double totalStockValue;

  /// Today's gross sales amount and items sold (for the dashboard banner).
  final double todaySalesAmount;
  final int todayItemsSold;

  final DateTime generatedAt;

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
    required this.generatedAt,
  });

  bool get hasAlerts =>
      stockOutAlerts.isNotEmpty ||
      expiryAlerts.isNotEmpty ||
      deadStockAlerts.isNotEmpty;

  int get alertCount =>
      stockOutAlerts.length + expiryAlerts.length + deadStockAlerts.length;
}
