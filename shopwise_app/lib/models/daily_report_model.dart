class DailyReportModel {
  final String date;
  final double totalSalesAmount;
  final double totalItemsSold;
  final double totalDueAmount;
  final List<SalesTrendPoint> salesTrend;

  const DailyReportModel({
    required this.date,
    required this.totalSalesAmount,
    required this.totalItemsSold,
    required this.totalDueAmount,
    required this.salesTrend,
  });

  factory DailyReportModel.fromJson(Map<String, dynamic> json) =>
      DailyReportModel(
        date: json['date']?.toString() ?? '',
        totalSalesAmount: _number(json['total_sales_amount']),
        totalItemsSold: _number(json['total_items_sold']),
        totalDueAmount: _number(json['total_due_amount']),
        salesTrend: (json['sales_trend'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SalesTrendPoint.fromJson)
            .toList(growable: false),
      );

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

class SalesTrendPoint {
  final String date;
  final double salesAmount;

  const SalesTrendPoint({required this.date, required this.salesAmount});

  factory SalesTrendPoint.fromJson(Map<String, dynamic> json) =>
      SalesTrendPoint(
        date: json['date']?.toString() ?? '',
        salesAmount: DailyReportModel._number(json['sales_amount']),
      );
}
