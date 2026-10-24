import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/daily_report_model.dart';
import '../../../providers/reports_provider.dart';

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(reportsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportsProvider);
    final report = state.summary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
            '\u09a6\u09c8\u09a8\u09bf\u0995 \u09b0\u09bf\u09aa\u09cb\u09b0\u09cd\u099f'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '\u0986\u09aa\u09a1\u09c7\u099f',
            onPressed: state.isLoading
                ? null
                : () => ref.read(reportsProvider.notifier).load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(reportsProvider.notifier).load(),
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.primary.withOpacity(0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '\u0986\u099c\u0995\u09c7\u09b0 \u09b8\u09be\u09b0\u09be\u0982\u09b6',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 14)),
                        SizedBox(height: 8),
                        Text(
                            '\u09b8\u09be\u09b0\u09be\u09a6\u09bf\u09a8\u09c7\u09b0 \u09ac\u09bf\u0995\u09cd\u09b0\u09bf',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (state.isLoading && report == null)
                    const SizedBox.square(
                        dimension: 28,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                  else
                    Text('\u09F3${_amount(report?.totalSalesAmount ?? 0)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            if (state.error != null && report == null) ...[
              const SizedBox(height: 14),
              _ErrorCard(
                  message: state.error!,
                  onRetry: () => ref.read(reportsProvider.notifier).load()),
            ],
            if (report != null) ...[
              const SizedBox(height: 20),
              _StatCard(
                title:
                    '\u09ae\u09cb\u099f \u09ac\u09bf\u0995\u09cd\u09b0\u09bf',
                value: '\u09F3${_amount(report.totalSalesAmount)}',
                icon: Icons.trending_up_rounded,
                colors: const [Color(0xFFFF9800), Color(0xFFFFB74D)],
              ),
              const SizedBox(height: 12),
              _StatCard(
                title:
                    '\u09ac\u09bf\u0995\u09cd\u09b0\u09bf\u09a4 \u09aa\u09a3\u09cd\u09af\u09c7\u09b0 \u09aa\u09b0\u09bf\u09ae\u09be\u09a3',
                value: _quantity(report.totalItemsSold),
                icon: Icons.shopping_basket_outlined,
                colors: const [Color(0xFF2196F3), Color(0xFF64B5F6)],
              ),
              const SizedBox(height: 12),
              _StatCard(
                title:
                    '\u09ac\u09be\u0995\u09bf \u09aa\u09be\u0993\u09a8\u09be',
                value: '\u09F3${_amount(report.totalDueAmount)}',
                icon: Icons.account_balance_wallet_outlined,
                colors: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
              ),
              const SizedBox(height: 24),
              const Text(
                  '\u0997\u09a4 \u09b8\u09be\u09a4 \u09a6\u09bf\u09a8\u09c7\u09b0 \u09ac\u09bf\u0995\u09cd\u09b0\u09bf',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _SalesTrendCard(points: report.salesTrend),
            ],
            if (state.isLoading && report != null)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final List<Color> colors;

  const _StatCard(
      {required this.title,
      required this.value,
      required this.icon,
      required this.colors});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
                color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 14))),
            const SizedBox(width: 8),
            Flexible(
                child: Text(value,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary))),
          ],
        ),
      );
}

class _SalesTrendCard extends StatelessWidget {
  final List<SalesTrendPoint> points;

  const _SalesTrendCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final safePoints = points.length == 7 ? points : const <SalesTrendPoint>[];
    final maxSales = safePoints.fold<double>(
        0, (max, point) => point.salesAmount > max ? point.salesAmount : max);
    final maxY = maxSales == 0 ? 100.0 : maxSales * 1.2;

    return Container(
      height: 260,
      padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x12000000), blurRadius: 14, offset: Offset(0, 5))
          ]),
      child: safePoints.isEmpty
          ? const Center(
              child: Text(
                  '\u09ac\u09bf\u0995\u09cd\u09b0\u09bf\u09b0 \u09a4\u09a5\u09cd\u09af \u09aa\u09be\u0993\u09df\u09be \u09af\u09be\u09df\u09a8\u09bf'))
          : LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= safePoints.length)
                          return const SizedBox.shrink();
                        return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(_weekday(safePoints[index].date),
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary)));
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: safePoints
                        .asMap()
                        .entries
                        .map((entry) => FlSpot(
                            entry.key.toDouble(), entry.value.salesAmount))
                        .toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 4,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withOpacity(0.25),
                              AppColors.primary.withOpacity(0.02)
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter)),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Text(message, textAlign: TextAlign.center),
            TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text(
                    '\u0986\u09ac\u09be\u09b0 \u099a\u09c7\u09b7\u09cd\u099f\u09be'))
          ]),
        ),
      );
}

String _amount(double value) => value.toStringAsFixed(2);

String _quantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(2);

String _weekday(String date) {
  final weekday = DateTime.tryParse(date)?.weekday ?? 1;
  const labels = [
    '\u09b8\u09cb\u09ae',
    '\u09ae\u0999\u09cd\u0997\u09b2',
    '\u09ac\u09c1\u09a7',
    '\u09ac\u09c3\u09b9\u09b8\u09cd\u09aa\u09a4\u09bf',
    '\u09b6\u09c1\u0995\u09cd\u09b0',
    '\u09b6\u09a8\u09bf',
    '\u09b0\u09ac\u09bf'
  ];
  return labels[weekday - 1];
}
