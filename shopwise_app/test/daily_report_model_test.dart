import 'package:flutter_test/flutter_test.dart';
import 'package:shopwise_app/models/daily_report_model.dart';

void main() {
  test('DailyReportModel parses MySQL decimal strings and weekly points', () {
    final report = DailyReportModel.fromJson({
      'date': '2026-10-25',
      'total_sales_amount': '45.50',
      'total_items_sold': '2.50',
      'total_due_amount': '10.25',
      'sales_trend': [
        {'date': '2026-10-25', 'sales_amount': '45.50'},
      ],
    });
    expect(report.totalSalesAmount, 45.5);
    expect(report.totalItemsSold, 2.5);
    expect(report.totalDueAmount, 10.25);
    expect(report.salesTrend.single.salesAmount, 45.5);
  });
}
