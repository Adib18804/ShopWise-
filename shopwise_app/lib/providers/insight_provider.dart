import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/batch_model.dart';
import '../models/insight_models.dart';
import '../models/product_model.dart';
import 'auth_provider.dart';

/// State for the Smart Assistant summary.
class InsightsState {

  const InsightsState({this.isLoading = false, this.summary, this.error});
  final bool isLoading;
  final SmartSummary? summary;
  final String? error;

  InsightsState copyWith({
    bool? isLoading,
    SmartSummary? summary,
    String? error,
  }) =>
      InsightsState(
        isLoading: isLoading ?? this.isLoading,
        summary: summary ?? this.summary,
        error: error,
      );
}

/// Computes the rule-based Smart Assistant summary from Firestore.
///
/// It reads the three relevant collections for the signed-in shop and applies
/// the project's rule-based math (no ML):
///
/// * **Stock-out:** `daysRemaining = currentStock / avgDailySales7`.
///   Alert when `daysRemaining < 5`, or when already out of stock.
/// * **Expiry:** batches expiring within 30 days (with 7/14/30 breakdown) and
///   `valueAtRisk = purchasePrice * quantity`; the "value at risk" headline
///   uses the next-14-days window per the spec.
/// * **Dead stock:** products with stock but no sales in the last 30 days,
///   guarded by a product-age check so new products are not mis-flagged.
class InsightsNotifier extends StateNotifier<InsightsState> {
  InsightsNotifier(this._ref) : super(const InsightsState());

  final Ref _ref;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// Recomputes the summary for the signed-in shop. Safe to call repeatedly.
  Future<void> load() async {
    final shopId = _ref.read(authProvider).shopId;
    if (shopId == null || shopId.isEmpty) {
      state = const InsightsState(error: 'প্রথমে লগইন করুন');
      return;
    }

    state = InsightsState(isLoading: true, summary: state.summary);
    try {
      final products = await _fetchProducts(shopId);
      final batches = await _fetchBatches(shopId);
      final invoices =
          await _fetchRecentInvoices(shopId, const Duration(days: 30));
      final summary = _compute(products, batches, invoices);
      state = InsightsState(summary: summary);
    } catch (error) {
      state = InsightsState(
        summary: state.summary,
        error: _errorMessage(error),
      );
    }
  }

  void clearError() => state = state.copyWith();

  // ---------------------------------------------------------------------------
  // Firestore reads
  // ---------------------------------------------------------------------------

  Future<List<ProductModel>> _fetchProducts(String shopId) async {
    final snap = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('products')
        .get();
    return snap.docs
        .map((d) => ProductModel.fromFirestore(d, shopId: shopId))
        .toList();
  }

  Future<List<BatchModel>> _fetchBatches(String shopId) async {
    final snap = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('batches')
        .get();
    return snap.docs
        .map((d) => BatchModel.fromFirestore(d, shopId: shopId))
        .toList();
  }

  Future<List<_InvoiceRead>> _fetchRecentInvoices(
    String shopId,
    Duration window,
  ) async {
    final since = DateTime.now().subtract(window);
    final snap = await _firestore
        .collection('shops')
        .doc(shopId)
        .collection('invoices')
        .where('created_at', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
        .get();

    return snap.docs.map(_InvoiceRead.fromDoc).toList();
  }

  // ---------------------------------------------------------------------------
  // Rule-based analysis
  // ---------------------------------------------------------------------------

  SmartSummary _compute(
    List<ProductModel> products,
    List<BatchModel> batches,
    List<_InvoiceRead> invoices,
  ) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Index products by their legacy int id so invoice/batch product ids (which
    // hash the Firestore doc id the same way) resolve back to the product.
    final productsById = <int, ProductModel>{
      for (final p in products) p.id: p,
    };

    // Aggregate sales velocity from recent invoices.
    final sales7 = <int, double>{}; // product id -> qty sold in last 7 days
    final soldInLast30 = <int>{}; // products that sold in the last 30 days
    final lastSaleDate = <int, DateTime>{}; // last sale date (within window)
    double todaySalesAmount = 0;
    var todayItemsSold = 0;
    // Profit: sum(selling_price × qty) – sum(purchase_price × qty) for today.
    double todayRevenue = 0; // = gross sales (same as todaySalesAmount)
    double todayCOGS = 0;    // cost of goods sold today (from invoice items)

    // Average purchase price per product (weighted across all active batches).
    final avgPurchasePriceByProduct = <int, double>{};
    {
      final totalQtyByProduct = <int, double>{};
      final totalCostByProduct = <int, double>{};
      for (final b in batches) {
        if (b.quantity <= 0) continue;
        totalQtyByProduct[b.productId] =
            (totalQtyByProduct[b.productId] ?? 0) + b.quantity;
        totalCostByProduct[b.productId] =
            (totalCostByProduct[b.productId] ?? 0) +
                b.quantity * b.purchasePrice;
      }
      for (final pid in totalQtyByProduct.keys) {
        final qty = totalQtyByProduct[pid]!;
        if (qty > 0) {
          avgPurchasePriceByProduct[pid] = totalCostByProduct[pid]! / qty;
        }
      }
    }

    for (final inv in invoices) {
      final isToday = !inv.createdAt.isBefore(todayStart);
      if (isToday) {
        todaySalesAmount += inv.totalAmount;
        todayRevenue += inv.totalAmount;
      }
      final in7 = inv.createdAt.isAfter(sevenDaysAgo);
      final in30 = inv.createdAt.isAfter(thirtyDaysAgo);

      for (final item in inv.items) {
        if (item.productId.isEmpty) continue;
        final pid = _stableId(item.productId);
        if (in7) sales7[pid] = (sales7[pid] ?? 0) + item.quantity;
        if (in30) soldInLast30.add(pid);
        final existing = lastSaleDate[pid];
        if (existing == null || inv.createdAt.isAfter(existing)) {
          lastSaleDate[pid] = inv.createdAt;
        }
        if (isToday) {
          todayItemsSold += item.quantity.round();
          // COGS: use batch avg purchase price when available; fall back to
          // the product's default purchase price.
          final avgCost = avgPurchasePriceByProduct[pid] ??
              (productsById[pid]?.defaultPurchasePrice ?? 0);
          todayCOGS += item.quantity * avgCost;
        }
      }
    }

    final todayEstimatedProfit = todayRevenue - todayCOGS;

    // Cost value of stock on hand per product (from batches) + total.
    final batchValueByProduct = <int, double>{};
    for (final b in batches) {
      if (b.quantity <= 0) continue;
      batchValueByProduct[b.productId] =
          (batchValueByProduct[b.productId] ?? 0) + b.quantity * b.purchasePrice;
    }
    final totalStockValue =
        batchValueByProduct.values.fold<double>(0, (a, b) => a + b);

    // --- Stock-out prediction ---
    final stockOutAlerts = <StockOutAlert>[];
    for (final p in products) {
      if (!p.isActive) continue;
      final stock = p.totalStock;
      final avgDaily = (sales7[p.id] ?? 0) / 7;

      if (stock <= 0) {
        stockOutAlerts.add(StockOutAlert(
          productId: p.docId ?? '',
          productName: p.name,
          unit: p.unit,
          currentStock: stock,
          avgDailySales: avgDaily,
          daysRemaining: 0,
          suggestedRestock: _suggestRestock(p, avgDaily),
          severity: StockOutSeverity.outOfStock,
        ),);
        continue;
      }

      if (avgDaily > 0) {
        final days = stock / avgDaily;
        if (days < 5) {
          stockOutAlerts.add(StockOutAlert(
            productId: p.docId ?? '',
            productName: p.name,
            unit: p.unit,
            currentStock: stock,
            avgDailySales: avgDaily,
            daysRemaining: days.round().clamp(0, 999),
            suggestedRestock: _suggestRestock(p, avgDaily),
            severity: days < 2
                ? StockOutSeverity.critical
                : StockOutSeverity.warning,
          ),);
        }
      }
    }
    stockOutAlerts.sort((a, b) => a.daysRemaining.compareTo(b.daysRemaining));

    // --- Expiry intelligence ---
    final expiryAlerts = <ExpiryAlert>[];
    double totalExpiryValueAtRisk = 0;
    double expiredValue = 0;
    var count7 = 0;
    var count14 = 0;
    var count30 = 0;
    var expiredCount = 0;

    for (final b in batches) {
      if (b.expiryDate == null || b.quantity <= 0) continue;
      final days = b.calculatedDaysUntilExpiry ?? 0;
      if (days > 30) continue; // far from expiry, not an alert

      final product = productsById[b.productId];
      final valueAtRisk = b.purchasePrice * b.quantity;
      final severity = days < 0
          ? ExpirySeverity.expired
          : days <= 7
              ? ExpirySeverity.critical
              : days <= 14
                  ? ExpirySeverity.warning
                  : ExpirySeverity.notice;

      expiryAlerts.add(ExpiryAlert(
        batchId: b.docId ?? '',
        productId: product?.docId ?? '',
        productName: product?.name ?? 'Unknown',
        batchNumber: b.batchNumber,
        daysUntilExpiry: days,
        quantity: b.quantity,
        purchasePrice: b.purchasePrice,
        valueAtRisk: valueAtRisk,
        severity: severity,
      ),);

      if (days < 0) {
        expiredCount++;
        expiredValue += valueAtRisk;
      } else if (days <= 7) {
        count7++;
        count14++;
        count30++;
        totalExpiryValueAtRisk += valueAtRisk;
      } else if (days <= 14) {
        count14++;
        count30++;
        totalExpiryValueAtRisk += valueAtRisk;
      } else {
        count30++;
      }
    }
    expiryAlerts.sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

    // --- Dead stock ---
    final deadStockAlerts = <DeadStockAlert>[];
    for (final p in products) {
      if (!p.isActive || p.totalStock <= 0) continue;
      // A product must have existed long enough to evaluate "30 days no sale".
      final ageDays = now.difference(p.createdAt).inDays;
      if (ageDays < 30) continue;
      if (soldInLast30.contains(p.id)) continue;

      deadStockAlerts.add(DeadStockAlert(
        productId: p.docId ?? '',
        productName: p.name,
        unit: p.unit,
        stockQuantity: p.totalStock,
        stockValue: batchValueByProduct[p.id] ??
            p.totalStock * p.defaultPurchasePrice,
        lastSaleDate: lastSaleDate[p.id],
      ),);
    }
    deadStockAlerts.sort((a, b) => b.stockValue.compareTo(a.stockValue));

    return SmartSummary(
      stockOutAlerts: stockOutAlerts,
      expiryAlerts: expiryAlerts,
      deadStockAlerts: deadStockAlerts,
      totalExpiryValueAtRisk: totalExpiryValueAtRisk,
      expiredValue: expiredValue,
      expiryCount7Days: count7,
      expiryCount14Days: count14,
      expiryCount30Days: count30,
      expiredCount: expiredCount,
      totalProducts: products.length,
      totalActiveProducts: products.where((p) => p.isActive).length,
      totalStockValue: totalStockValue,
      todaySalesAmount: todaySalesAmount,
      todayItemsSold: todayItemsSold,
      todayEstimatedProfit: todayEstimatedProfit,
      generatedAt: now,
    );
  }

  /// Suggested restock quantity to cover `targetStockDays` at the current pace.
  /// Falls back to the reorder level when there is no sales velocity.
  double _suggestRestock(ProductModel p, double avgDaily) {
    if (avgDaily > 0) {
      final target = p.targetStockDays * avgDaily;
      final suggested = target - p.totalStock;
      return suggested < 0 ? 0 : suggested;
    }
    return p.minimumStock > 0 ? p.minimumStock : 0;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    if (error is FirebaseException) {
      return error.message ?? 'তথ্য বিশ্লেষণ করা যায়নি। আবার চেষ্টা করুন।';
    }
    return 'তথ্য বিশ্লেষণ করা যায়নি। আবার চেষ্টা করুন।';
  }

  /// Same FNV-1a hash used by the models so invoice/batch product ids resolve.
  static int _stableId(String value) {
    var hash = 0x811c9dc5;
    for (final byte in value.codeUnits) {
      hash = ((hash ^ byte) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }
}

final insightsProvider =
    StateNotifierProvider<InsightsNotifier, InsightsState>(InsightsNotifier.new);

// ---------------------------------------------------------------------------
// Lightweight invoice read helpers (kept local until the sales engine in STEP 4
// formalises the Firestore invoice model).
// ---------------------------------------------------------------------------

class _InvoiceRead {

  _InvoiceRead({
    required this.createdAt,
    required this.totalAmount,
    required this.items,
  });

  factory _InvoiceRead.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final createdAt = _toDateTime(data['created_at']);
    final totalAmount = _toDouble(data['total_amount']);
    final rawItems = data['items'];
    final items = <_InvoiceItemRead>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        items.add(_InvoiceItemRead(
          productId: map['product_id']?.toString() ?? '',
          quantity: _toDouble(map['quantity']),
        ),);
      }
    }
    return _InvoiceRead(
      createdAt: createdAt,
      totalAmount: totalAmount,
      items: items,
    );
  }
  final DateTime createdAt;
  final double totalAmount;
  final List<_InvoiceItemRead> items;

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}

class _InvoiceItemRead {

  const _InvoiceItemRead({required this.productId, required this.quantity});
  final String productId;
  final double quantity;
}
