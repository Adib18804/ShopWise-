import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../core/network/api_exception.dart';
import '../models/daily_report_model.dart';

/// Daily report repository backed by Cloud Firestore.
///
/// Firestore has no SQL SUM, so invoices for the last 7 days are fetched once
/// and the daily summary (today's totals) + 7-day sales chart are aggregated
/// in Dart on the client.
class ReportsRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw ApiException(message: 'প্রথমে লগইন করুন');
    }
    return uid;
  }

  Future<DailyReportModel> getDailySummary() async {
    try {
      final uid = _uid;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final sevenDaysAgoStart = todayStart.subtract(const Duration(days: 6));

      final snap = await _firestore
          .collection('shops')
          .doc(uid)
          .collection('invoices')
          .where('created_at',
              isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgoStart))
          .get();

      final invoices = snap.docs.map((d) => _Invoice(d.data())).toList();

      // Today's totals.
      double todaySales = 0;
      double todayDue = 0;
      double todayItems = 0;
      for (final inv in invoices) {
        if (!inv.createdAt.isBefore(todayStart)) {
          todaySales += inv.totalAmount;
          if (inv.dueAmount > 0) todayDue += inv.dueAmount;
          todayItems += inv.itemsQuantity;
        }
      }

      // 7-day chart (oldest -> newest), 7 points.
      final trend = <SalesTrendPoint>[];
      for (var i = 6; i >= 0; i--) {
        final day = todayStart.subtract(Duration(days: i));
        final next = day.add(const Duration(days: 1));
        var amount = 0.0;
        for (final inv in invoices) {
          if (!inv.createdAt.isBefore(day) && inv.createdAt.isBefore(next)) {
            amount += inv.totalAmount;
          }
        }
        trend.add(SalesTrendPoint(date: _isoDate(day), salesAmount: amount));
      }

      return DailyReportModel(
        date: _isoDate(todayStart),
        totalSalesAmount: todaySales,
        totalItemsSold: todayItems,
        totalDueAmount: todayDue,
        salesTrend: trend,
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      if (error is FirebaseException) {
        throw ApiException(
            message: error.message ?? 'রিপোর্ট লোড করা যায়নি');
      }
      throw ApiException(message: 'রিপোর্ট লোড করা যায়নি');
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Lightweight invoice view used only for client-side aggregation.
class _Invoice {
  final DateTime createdAt;
  final double totalAmount;
  final double dueAmount;
  final double itemsQuantity;

  _Invoice(Map<String, dynamic> data)
      : createdAt = _toDateTime(data['created_at']),
        totalAmount = _toDouble(data['total_amount']),
        dueAmount = _toDouble(data['due_amount']),
        itemsQuantity = _sumQuantities(data['items']);

  static double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  static double _sumQuantities(dynamic items) {
    if (items is! List) return 0.0;
    var sum = 0.0;
    for (final raw in items) {
      if (raw is Map) sum += _toDouble(raw['quantity']);
    }
    return sum;
  }
}
