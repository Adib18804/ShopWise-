import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/insight_models.dart';
import '../../../models/shop_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/insight_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../services/notification_service.dart';
import '../../customers/screens/customer_list_screen.dart';
import '../../products/screens/product_form_screen.dart';
import '../../sales/screens/create_sale_screen.dart';

/// Home tab of the ShopWise shell — redesigned with the brand design system.
///
/// Business logic (InsightsNotifier, SmartSummary, notification triggers) is
/// identical to the previous version. New additions:
///   • 7-day sales trend line chart (fl_chart) below the summary hero card.
///   • Full "Why am I seeing this?" bottom sheet per stock-out recommendation.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAll);
  }

  Future<void> _loadAll() async {
    ref.read(customerProvider.notifier).init();
    // Load insights (Smart Assistant data) and reports (7-day chart).
    await Future.wait([
      ref.read(insightsProvider.notifier).load(),
      ref.read(reportsProvider.notifier).load(),
    ]);
    if (!mounted) return;
    final summary = ref.read(insightsProvider).summary;
    if (summary == null) return;
    final shopType = ref.read(shopTypeProvider);
    debugPrint(
      'Checking notification triggers: shopType=$shopType, '
      'expiryAlerts=${summary.expiryAlerts.length}, '
      'stockOutAlerts=${summary.stockOutAlerts.length}.',
    );
    if (shopType != ShopType.stationery &&
        shopType != ShopType.library &&
        summary.expiryAlerts.isNotEmpty) {
      debugPrint(
        'Notification trigger: expiry warning for '
        '${summary.expiryAlerts.length} alert(s).',
      );
      await NotificationService.instance
          .showExpiryWarning(summary.expiryAlerts.length);
    }
    if (summary.stockOutAlerts.isNotEmpty) {
      debugPrint(
        'Notification trigger: stock-out warning for '
        '${summary.stockOutAlerts.length} alert(s).',
      );
      await NotificationService.instance
          .showStockOutWarning(summary.stockOutAlerts.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = ref.watch(appLocalizationsProvider);
    final auth = ref.watch(authProvider);
    final shop = ref.watch(shopProvider);
    final shopType = ref.watch(shopTypeProvider);
    final insights = ref.watch(insightsProvider);
    final reports = ref.watch(reportsProvider);
    final customers = ref.watch(customerProvider).customers;
    final summary = insights.summary;
    final pendingDuesCount =
        customers.where((customer) => customer.hasDue).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final horizontalPadding = compact
            ? 12.0
            : constraints.maxWidth >= 720
                ? 24.0
                : 16.0;
        return DefaultTextStyle(
          style: DefaultTextStyle.of(context).style,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
          child: Scaffold(
            backgroundColor: AppColors.background,
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(
                MediaQuery.paddingOf(context).top + 52,
              ),
              child: _DashboardAppBar(
                shopName: shop.shop?.shopName ?? 'ShopWise',
                userName: auth.user?.name ?? '',
                l: l,
              ),
            ),
            body: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _loadAll,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        horizontalPadding, 8, horizontalPadding, 32),
                    children: [
                      // Error banner
                      if (insights.error != null) ...[
                        _ErrorBanner(
                          message: l.refreshFailed,
                          retryLabel: l.retry,
                          onRetry: _loadAll,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Smart summary hero card ──────────────────────────────────
                      _SmartSummaryCard(
                        summary: summary,
                        isLoading: insights.isLoading,
                        l: l,
                        showExpiry: shopType != ShopType.stationery &&
                            shopType != ShopType.library,
                        expiryFirst: shopType == ShopType.pharmacy,
                      ),
                      const SizedBox(height: 12),

                      // ── 7-day sales trend chart ──────────────────────────────────
                      _SalesTrendCard(
                        trend: reports.summary?.salesTrend ?? const [],
                        isLoading: reports.isLoading && reports.summary == null,
                        l: l,
                      ),
                      const SizedBox(height: 20),

                      // ── Quick actions ────────────────────────────────────────────
                      _SectionHeader(l.quickActions),
                      const SizedBox(height: 12),
                      _QuickActionsRow(
                          l: l, isLibrary: shopType == ShopType.library),
                      const SizedBox(height: 24),

                      // ── Attention needed — alert list ────────────────────────────
                      _SectionHeader(l.smartInsights),
                      const SizedBox(height: 12),
                      _AttentionList(
                        summary: summary,
                        isLoading: insights.isLoading && summary == null,
                        l: l,
                        showExpiry: shopType != ShopType.stationery &&
                            shopType != ShopType.library,
                        expiryFirst: shopType == ShopType.pharmacy,
                        onStockOut: () => _showSheet(
                          context,
                          l,
                          l.stockOutRisk,
                          AppColors.riskCritical,
                          Icons.error_outline_rounded,
                          _stockOutTiles(summary, l),
                        ),
                        onExpiry: () => _showSheet(
                          context,
                          l,
                          l.expiryRisk,
                          AppColors.riskHigh,
                          Icons.schedule_rounded,
                          _expiryTiles(summary, l),
                        ),
                        onDeadStock: () => _showSheet(
                          context,
                          l,
                          l.deadStock,
                          AppColors.info,
                          Icons.hourglass_bottom_rounded,
                          _deadStockTiles(summary, l),
                        ),
                      ),
                      if (pendingDuesCount > 0) ...[
                        const SizedBox(height: 10),
                        _PendingDuesAlert(
                          count: pendingDuesCount,
                          isBn: l.isBn,
                          isLibrary: shopType == ShopType.library,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CustomerListScreen(),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // ── Profit & Loss ────────────────────────────────────────────
                      if (summary != null) ...[
                        _SectionHeader(l.isBn ? 'লাভ-ক্ষতি' : 'Profit & Loss'),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _PLCard(
                                icon: Icons.trending_up_rounded,
                                label: l.todayProfit,
                                value: l
                                    .formatAmount(summary.todayEstimatedProfit),
                                positive: summary.todayEstimatedProfit >= 0,
                              ),
                            ),
                            if (shopType != ShopType.stationery &&
                                shopType != ShopType.library) ...[
                              const SizedBox(width: 12),
                              Expanded(
                                child: _PLCard(
                                  icon: Icons.report_outlined,
                                  label: l.potentialLoss,
                                  value: l.formatAmount(summary.expiredValue),
                                  positive: summary.expiredValue == 0,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Smart recommendation card ────────────────────────────────
                      if (summary != null && summary.stockOutAlerts.isNotEmpty)
                        _SmartRecommendationCard(summary: summary, l: l),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Sheet data builders ────────────────────────────────────────────────────

  List<_SheetAlertItem> _stockOutTiles(SmartSummary? s, AppLocalizations l) =>
      (s?.stockOutAlerts ?? <StockOutAlert>[]).map((a) {
        final color = a.severity == StockOutSeverity.outOfStock
            ? AppColors.riskCritical
            : a.severity == StockOutSeverity.critical
                ? AppColors.riskHigh
                : AppColors.riskMedium;
        return _SheetAlertItem(
          title: a.productName,
          subtitle: a.severity == StockOutSeverity.outOfStock
              ? l.outOfStock
              : l.runsOutIn(a.daysRemaining),
          meta: '${l.currentStock}: ${l.formatQty(a.currentStock, a.unit)} · '
              '${l.suggestedRestock}: ~${l.formatQty(a.suggestedRestock, a.unit)}',
          color: color,
        );
      }).toList();

  List<_SheetAlertItem> _expiryTiles(SmartSummary? s, AppLocalizations l) =>
      (s?.expiryAlerts ?? <ExpiryAlert>[]).map((a) {
        final color = a.severity == ExpirySeverity.expired
            ? AppColors.riskCritical
            : a.severity == ExpirySeverity.critical
                ? AppColors.riskHigh
                : AppColors.riskMedium;
        return _SheetAlertItem(
          title: a.productName,
          subtitle: a.daysUntilExpiry < 0
              ? l.expired
              : l.expiresIn(a.daysUntilExpiry),
          meta: '${l.batch}: ${a.batchNumber ?? "—"} · '
              '${l.quantity}: ${l.formatQty(a.quantity)}',
          trailing: l.formatAmount(a.valueAtRisk),
          color: color,
        );
      }).toList();

  List<_SheetAlertItem> _deadStockTiles(SmartSummary? s, AppLocalizations l) =>
      (s?.deadStockAlerts ?? <DeadStockAlert>[])
          .map(
            (a) => _SheetAlertItem(
              title: a.productName,
              subtitle: l.noSalesIn30,
              meta:
                  '${l.currentStock}: ${l.formatQty(a.stockQuantity, a.unit)} · '
                  '${l.lastSale}: ${a.lastSaleDate == null ? l.neverSold : l.formatDate(a.lastSaleDate!)}',
              trailing: l.formatAmount(a.stockValue),
              color: AppColors.info,
            ),
          )
          .toList();

  Future<void> _showSheet(
    BuildContext context,
    AppLocalizations l,
    String title,
    Color color,
    IconData icon,
    List<_SheetAlertItem> items,
  ) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black38,
        builder: (_) => _AlertBottomSheet(
          title: title,
          color: color,
          icon: icon,
          items: items,
          l: l,
        ),
      );
}

// =============================================================================
// App bar
// =============================================================================

class _DashboardAppBar extends StatelessWidget {
  const _DashboardAppBar({
    required this.shopName,
    required this.userName,
    required this.l,
  });
  final String shopName;
  final String userName;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final initials = userName.isNotEmpty ? userName[0].toUpperCase() : 'S';
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(Icons.store_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  l.welcome,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const _LangToggle(),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryLight.withValues(alpha: 0.2),
            child: Text(
              initials,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('shopName', shopName));
    properties.add(StringProperty('userName', userName));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
  }
}

class _LangToggle extends ConsumerWidget {
  const _LangToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider).language;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(
            lang == AppLanguage.bn,
            'BN',
            () =>
                ref.read(languageProvider.notifier).setLanguage(AppLanguage.bn),
          ),
          _pill(
            lang == AppLanguage.en,
            'EN',
            () =>
                ref.read(languageProvider.notifier).setLanguage(AppLanguage.en),
          ),
        ],
      ),
    );
  }

  Widget _pill(bool active, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      );
}

// =============================================================================
// Smart Summary hero card
// =============================================================================

class _SmartSummaryCard extends StatelessWidget {
  const _SmartSummaryCard({
    required this.summary,
    required this.isLoading,
    required this.l,
    required this.showExpiry,
    required this.expiryFirst,
  });
  final SmartSummary? summary;
  final bool isLoading;
  final AppLocalizations l;
  final bool showExpiry;
  final bool expiryFirst;

  @override
  Widget build(BuildContext context) {
    final stockOut = summary?.stockOutAlerts.length ?? 0;
    final expiring = summary?.expiryAlerts.length ?? 0;
    final todaySales = summary?.todaySalesAmount ?? 0;
    final compact = MediaQuery.sizeOf(context).width < 360;

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  l.todaySummary,
                  maxLines: 1,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  l.formatDate(DateTime.now()),
                  maxLines: 1,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isLoading ? '...' : l.formatAmount(todaySales),
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 28 : 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            l.todaysSales,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (showExpiry && expiryFirst)
                _AlertChip(
                  label: l.isBn ? 'মেয়াদ ঝুঁকি' : 'Expiry Risk',
                  count: expiring,
                  loading: isLoading,
                ),
              if (showExpiry && expiryFirst) const SizedBox(width: 10),
              _AlertChip(
                label: l.isBn ? 'কম স্টক' : 'Low Stock',
                count: stockOut,
                loading: isLoading,
              ),
              if (showExpiry && !expiryFirst) ...[
                const SizedBox(width: 10),
                _AlertChip(
                  label: l.isBn ? 'মেয়াদ ঝুঁকি' : 'Expiry Risk',
                  count: expiring,
                  loading: isLoading,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SmartSummary?>('summary', summary));
    properties.add(DiagnosticsProperty<bool>('isLoading', isLoading));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
    properties.add(DiagnosticsProperty<bool>('showExpiry', showExpiry));
    properties.add(DiagnosticsProperty<bool>('expiryFirst', expiryFirst));
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip(
      {required this.label, required this.count, required this.loading});
  final String label;
  final int count;
  final bool loading;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(width: 6),
            Text(
              loading ? '...' : count.toString().padLeft(2, '0'),
              style: const TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
    properties.add(IntProperty('count', count));
    properties.add(DiagnosticsProperty<bool>('loading', loading));
  }
}

// =============================================================================
// Feature 4: 7-day sales trend chart
// =============================================================================

class _SalesTrendCard extends StatelessWidget {
  const _SalesTrendCard({
    required this.trend,
    required this.isLoading,
    required this.l,
  });
  final List<dynamic> trend; // List<SalesTrendPoint>
  final bool isLoading;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.isBn ? 'গত ৭ দিনের বিক্রি' : '7-Day Sales Trend',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Icon(
                  Icons.show_chart_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : trend.length < 7
                      ? Center(
                          child: Text(
                            l.isBn ? 'তথ্য নেই' : 'No data yet',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        )
                      : _TrendLineChart(trend: trend, l: l),
            ),
          ],
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<dynamic>('trend', trend));
    properties.add(DiagnosticsProperty<bool>('isLoading', isLoading));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
  }
}

class _TrendLineChart extends StatelessWidget {
  const _TrendLineChart({required this.trend, required this.l});
  final List<dynamic> trend;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    // trend is List<SalesTrendPoint> from DailyReportModel.
    // Each has .date (String) and .salesAmount (double).
    final amounts = trend.map((p) {
      final dynamic pt = p;
      final amount = (pt.salesAmount as num?) ?? 0;
      return amount.toDouble();
    }).toList();

    final maxY = amounts.isEmpty
        ? 100.0
        : (amounts.reduce((a, b) => a > b ? a : b) * 1.2)
            .clamp(1.0, double.infinity);

    final spots = amounts
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value))
        .toList();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 2,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: AppColors.border,
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= trend.length) {
                  return const SizedBox.shrink();
                }
                final dynamic pt = trend[idx];
                final dateStr = (pt.date as String?) ?? '';
                final parsed = DateTime.tryParse(dateStr);
                final label = parsed == null
                    ? ''
                    : l.isBn
                        ? _bnWeekdayShort(parsed.weekday)
                        : _enWeekdayShort(parsed.weekday);
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.primary,
                strokeWidth: 1.5,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.18),
                  AppColors.primary.withValues(alpha: 0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: AppColors.primary,
            getTooltipItems: (spots) => spots
                .map(
                  (s) => LineTooltipItem(
                    l.formatAmount(s.y),
                    const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  static String _bnWeekdayShort(int w) =>
      ['সো', 'মঙ', 'বু', 'বৃ', 'শু', 'শ', 'র'][w - 1];
  static String _enWeekdayShort(int w) =>
      ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'][w - 1];

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IterableProperty<dynamic>('trend', trend));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
  }
}

// =============================================================================
// Quick actions
// =============================================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('text', text));
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.l, required this.isLibrary});
  final AppLocalizations l;
  final bool isLibrary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 360 ? 2 : 3;
          final spacing = 10.0;
          final cardWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          final cards = <Widget>[
            _QuickCard(
              icon: Icons.point_of_sale_rounded,
              label: isLibrary
                  ? (l.isBn ? 'বই ইস্যু' : 'Issue Book')
                  : (l.isBn ? 'বিক্রি করুন' : 'Record Sale'),
              iconColor: AppColors.primary,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const CreateSaleScreen()),
              ),
            ),
            _QuickCard(
              icon: Icons.add_box_rounded,
              label: l.isBn ? 'স্টক যোগ' : 'Add Stock',
              iconColor: AppColors.accent,
              onTap: () {},
            ),
            _QuickCard(
              icon: Icons.inventory_2_rounded,
              label: l.addProduct,
              iconColor: AppColors.success,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                    builder: (_) => const ProductFormScreen()),
              ),
            ),
          ];

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: cards
                .map((card) => SizedBox(width: cardWidth, child: card))
                .toList(),
          );
        },
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
    properties.add(DiagnosticsProperty<bool>('isLibrary', isLibrary));
  }
}

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          splashColor: iconColor.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(StringProperty('label', label));
    properties.add(ColorProperty('iconColor', iconColor));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
  }
}

// =============================================================================
// Attention list
// =============================================================================

class _AttentionList extends StatelessWidget {
  const _AttentionList({
    required this.summary,
    required this.isLoading,
    required this.l,
    required this.showExpiry,
    required this.expiryFirst,
    required this.onStockOut,
    required this.onExpiry,
    required this.onDeadStock,
  });
  final SmartSummary? summary;
  final bool isLoading;
  final AppLocalizations l;
  final bool showExpiry;
  final bool expiryFirst;
  final VoidCallback onStockOut;
  final VoidCallback onExpiry;
  final VoidCallback onDeadStock;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final stockAlert = summary?.stockOutAlerts.firstOrNull;
    final expiryAlert = showExpiry ? summary?.expiryAlerts.firstOrNull : null;
    final deadAlert = summary?.deadStockAlerts.firstOrNull;

    final hasAnyAlert = (summary?.stockOutAlerts.isNotEmpty ?? false) ||
        (showExpiry && (summary?.expiryAlerts.isNotEmpty ?? false)) ||
        (summary?.deadStockAlerts.isNotEmpty ?? false);

    if (!hasAnyAlert && summary != null) return _NoAlertsCard(l: l);

    final items = <Widget>[];
    final stockWidget = stockAlert == null
        ? null
        : _AlertListItem(
            icon: Icons.error_outline_rounded,
            accentColor: AppColors.riskCritical,
            title: stockAlert.productName,
            subtitle: stockAlert.severity == StockOutSeverity.outOfStock
                ? l.outOfStock
                : l.runsOutIn(stockAlert.daysRemaining),
            count: summary?.stockOutAlerts.length ?? 0,
            onTap: onStockOut,
          );
    final expiryWidget = expiryAlert == null
        ? null
        : _AlertListItem(
            icon: Icons.schedule_rounded,
            accentColor:
                expiryFirst ? AppColors.riskCritical : AppColors.riskHigh,
            title: expiryAlert.productName,
            subtitle: expiryAlert.daysUntilExpiry < 0
                ? l.expired
                : l.expiresIn(expiryAlert.daysUntilExpiry),
            count: summary?.expiryAlerts.length ?? 0,
            onTap: onExpiry,
          );
    final deadWidget = deadAlert == null
        ? null
        : _AlertListItem(
            icon: Icons.hourglass_bottom_rounded,
            accentColor: AppColors.info,
            title: deadAlert.productName,
            subtitle: l.noSalesIn30,
            count: summary?.deadStockAlerts.length ?? 0,
            onTap: onDeadStock,
          );
    final ordered = expiryFirst
        ? [expiryWidget, stockWidget, deadWidget]
        : [stockWidget, expiryWidget, deadWidget];
    for (final item in ordered.whereType<Widget>()) {
      if (items.isNotEmpty) items.add(const SizedBox(height: 8));
      items.add(item);
    }
    return Column(children: items);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SmartSummary?>('summary', summary));
    properties.add(DiagnosticsProperty<bool>('isLoading', isLoading));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
    properties.add(DiagnosticsProperty<bool>('showExpiry', showExpiry));
    properties.add(DiagnosticsProperty<bool>('expiryFirst', expiryFirst));
    properties
        .add(ObjectFlagProperty<VoidCallback>.has('onStockOut', onStockOut));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onExpiry', onExpiry));
    properties
        .add(ObjectFlagProperty<VoidCallback>.has('onDeadStock', onDeadStock));
  }
}

class _PendingDuesAlert extends StatelessWidget {
  const _PendingDuesAlert({
    required this.count,
    required this.isBn,
    required this.isLibrary,
    required this.onTap,
  });
  final int count;
  final bool isBn;
  final bool isLibrary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              border: Border.all(
                  color: AppColors.riskMedium.withValues(alpha: 0.45)),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.riskHigh,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isBn
                        ? '$count জন ${isLibrary ? 'সদস্য' : 'গ্রাহক'}-এর বাকি টাকা রয়েছে'
                        : 'You have $count ${isLibrary ? 'members' : 'customers'} with pending dues.',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('count', count));
    properties.add(DiagnosticsProperty<bool>('isBn', isBn));
    properties.add(DiagnosticsProperty<bool>('isLibrary', isLibrary));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
  }
}

class _AlertListItem extends StatelessWidget {
  const _AlertListItem({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.onTap,
  });
  final IconData icon;
  final Color accentColor;
  final String title;
  final String subtitle;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: accentColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (count > 1) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '+${count - 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                const Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textDisabled,
                ),
              ],
            ),
          ),
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(ColorProperty('accentColor', accentColor));
    properties.add(StringProperty('title', title));
    properties.add(StringProperty('subtitle', subtitle));
    properties.add(IntProperty('count', count));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
  }
}

class _NoAlertsCard extends StatelessWidget {
  const _NoAlertsCard({required this.l});
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: AppColors.success,
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                l.noAlerts,
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
  }
}

// =============================================================================
// Profit & Loss
// =============================================================================

class _PLCard extends StatelessWidget {
  const _PLCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.positive,
  });
  final IconData icon;
  final String label;
  final String value;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.success : AppColors.error;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(StringProperty('label', label));
    properties.add(StringProperty('value', value));
    properties.add(DiagnosticsProperty<bool>('positive', positive));
  }
}

// =============================================================================
// Feature 1: Smart recommendation card with full "Why" bottom sheet
// =============================================================================

class _SmartRecommendationCard extends StatelessWidget {
  const _SmartRecommendationCard({required this.summary, required this.l});
  final SmartSummary summary;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final topAlert = summary.stockOutAlerts.first;
    final suggestion = topAlert.suggestedRestock > 0
        ? l.formatQty(topAlert.suggestedRestock, topAlert.unit)
        : '—';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.96, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutBack,
      builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF8F2), Color(0xFFFFF1E0)],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l.isBn ? 'স্মার্ট পরামর্শ' : 'Smart Recommendation',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentDark,
                  ),
                ),
                const Spacer(),
                // "All recommendations" link
                if (summary.stockOutAlerts.length > 1)
                  GestureDetector(
                    onTap: () => _showAllRecommendations(context),
                    child: Text(
                      l.isBn ? 'সব দেখুন' : 'See all',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Recommendation body
            Text(
              l.isBn
                  ? '${topAlert.productName} এর স্টক কম হতে পারে। সাম্প্রতিক বিক্রির ভিত্তিতে ~$suggestion রিস্টক বিবেচনা করুন।'
                  : '${topAlert.productName} stock may need attention. Based on recent sales, consider restocking ~$suggestion.',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            // "Why am I seeing this?" — opens full bottom sheet
            GestureDetector(
              onTap: () => _showWhySheet(context, topAlert),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l.isBn ? 'কেন দেখছি?' : 'Why am I seeing this?',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWhySheet(BuildContext context, StockOutAlert alert) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => _WhyBottomSheet(alert: alert, l: l),
    );
  }

  void _showAllRecommendations(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => _AllRecommendationsSheet(summary: summary, l: l),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SmartSummary>('summary', summary));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
  }
}

// =============================================================================
// Feature 1: "Why am I seeing this?" — detailed explanation sheet
// =============================================================================

/// Deep-dive explanation sheet for a single stock-out alert.
/// Shows step-by-step logic in simple Bengali + English.
class _WhyBottomSheet extends StatelessWidget {
  const _WhyBottomSheet({required this.alert, required this.l});
  final StockOutAlert alert;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final isBn = l.isBn;

    // Derive plain-language numbers for the explanation.
    final soldLast7 = (alert.avgDailySales * 7).round();
    final currentStockStr = l.formatQty(alert.currentStock, alert.unit);
    final avgDailyStr = l.formatQty(alert.avgDailySales, alert.unit);
    final suggestionStr = alert.suggestedRestock > 0
        ? l.formatQty(alert.suggestedRestock, alert.unit)
        : '—';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Sheet header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isBn ? 'কেন এই পরামর্শ?' : 'Why this recommendation?',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        alert.productName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plain-language summary sentence
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      isBn
                          ? 'গত ৭ দিনে ${l.formatQty(soldLast7.toDouble(), alert.unit)} ${alert.productName} বিক্রি হয়েছে, '
                              'তাই আপনার স্টক আনুমানিক ${alert.daysRemaining} দিনের মধ্যে শেষ হবে।'
                          : 'In the last 7 days, $soldLast7 ${alert.unit} of ${alert.productName} '
                              'was sold, so your stock may run out in ~${alert.daysRemaining} day(s).',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.6,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Step-by-step logic blocks
                  Text(
                    isBn
                        ? 'লজিকটি এভাবে কাজ করে:'
                        : "Here's how the logic works:",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LogicStep(
                    step: 1,
                    title: isBn ? 'গড় দৈনিক বিক্রি' : 'Avg daily sales',
                    body: isBn
                        ? 'গত ৭ দিনে মোট ${l.formatQty(soldLast7.toDouble(), alert.unit)} বিক্রি ÷ ৭ দিন = দৈনিক ~$avgDailyStr'
                        : 'Total $soldLast7 ${alert.unit} sold ÷ 7 days = ~$avgDailyStr / day',
                  ),
                  const SizedBox(height: 8),
                  _LogicStep(
                    step: 2,
                    title: isBn ? 'বর্তমান স্টক' : 'Current stock',
                    body: isBn
                        ? 'আপনার কাছে এখন $currentStockStr আছে।'
                        : 'You currently have $currentStockStr in stock.',
                  ),
                  const SizedBox(height: 8),
                  _LogicStep(
                    step: 3,
                    title: isBn ? 'কত দিন চলবে' : 'Days remaining',
                    body: isBn
                        ? '$currentStockStr ÷ $avgDailyStr = আনুমানিক ${alert.daysRemaining} দিন'
                        : '$currentStockStr ÷ $avgDailyStr = ~${alert.daysRemaining} day(s)',
                    highlight: true,
                  ),
                  const SizedBox(height: 8),
                  _LogicStep(
                    step: 4,
                    title: isBn ? 'পরামর্শ' : 'Suggestion',
                    body: isBn
                        ? 'লক্ষ্যমাত্রা পূরণে ~$suggestionStr রিস্টক করার কথা বিবেচনা করুন। '
                            'চূড়ান্ত সিদ্ধান্ত সম্পূর্ণ আপনার।'
                        : 'Consider restocking ~$suggestionStr to meet your target stock level. '
                            'The final decision is entirely yours.',
                    highlight: true,
                  ),
                  const SizedBox(height: 20),

                  // Disclaimer
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isBn
                                ? 'এটি একটি আনুমানিক হিসাব। ShopWise কোনো সিদ্ধান্ত নেয় না — সিদ্ধান্ত সব সময় আপনার।'
                                : 'This is an estimate based on recent sales. '
                                    'ShopWise never acts automatically — you are always in control.',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<StockOutAlert>('alert', alert));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
  }
}

class _LogicStep extends StatelessWidget {
  const _LogicStep({
    required this.step,
    required this.title,
    required this.body,
    this.highlight = false,
  });
  final int step;
  final String title;
  final String body;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final color = highlight ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(
          color: highlight
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('step', step));
    properties.add(StringProperty('title', title));
    properties.add(StringProperty('body', body));
    properties.add(DiagnosticsProperty<bool>('highlight', highlight));
  }
}

/// Shows all stock-out alerts with their "Why" explanation in one sheet.
class _AllRecommendationsSheet extends StatelessWidget {
  const _AllRecommendationsSheet({required this.summary, required this.l});
  final SmartSummary summary;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.accent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l.isBn ? 'সব পরামর্শ' : 'All Recommendations',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: summary.stockOutAlerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final alert = summary.stockOutAlerts[i];
                  final soldLast7 = (alert.avgDailySales * 7).round();
                  final suggestion = alert.suggestedRestock > 0
                      ? l.formatQty(alert.suggestedRestock, alert.unit)
                      : '—';
                  return Material(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          barrierColor: Colors.black38,
                          builder: (_) => _WhyBottomSheet(alert: alert, l: l),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    alert.productName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    l.isBn
                                        ? 'গত ৭ দিনে ${l.formatQty(soldLast7.toDouble(), alert.unit)} বিক্রি · '
                                            '~$suggestion রিস্টক প্রয়োজন'
                                        : '$soldLast7 ${alert.unit} sold in 7 days · '
                                            '~$suggestion restock needed',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: AppColors.textDisabled,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SmartSummary>('summary', summary));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
  }
}

// =============================================================================
// Alert bottom sheet (generic — used by attentionList)
// =============================================================================

class _SheetAlertItem {
  const _SheetAlertItem({
    required this.title,
    required this.subtitle,
    required this.color,
    this.meta,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final String? meta;
  final String? trailing;
  final Color color;
}

class _AlertBottomSheet extends StatelessWidget {
  const _AlertBottomSheet({
    required this.title,
    required this.color,
    required this.icon,
    required this.items,
    required this.l,
  });
  final String title;
  final Color color;
  final IconData icon;
  final List<_SheetAlertItem> items;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 10),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  l.noAlertsHere,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        border: Border.all(
                            color: item.color.withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 44,
                            decoration: BoxDecoration(
                              color: item.color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: item.color,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (item.meta != null)
                                  Text(
                                    item.meta!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (item.trailing != null)
                            Text(
                              item.trailing!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: item.color,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('title', title));
    properties.add(ColorProperty('color', color));
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(IterableProperty<_SheetAlertItem>('items', items));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
  }
}

// =============================================================================
// Error banner
// =============================================================================

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Text(
                retryLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('message', message));
    properties.add(StringProperty('retryLabel', retryLabel));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onRetry', onRetry));
  }
}
