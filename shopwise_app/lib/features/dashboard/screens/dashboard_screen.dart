import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/insight_models.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/insight_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../services/notification_service.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../customers/screens/customer_list_screen.dart';
import '../../products/screens/product_form_screen.dart';
import '../../reports/screens/report_screen.dart';
import '../../sales/screens/create_sale_screen.dart';
import '../../sales/screens/sale_history_screen.dart';

/// Smart Assistant Dashboard.
///
/// • Today's summary banner (sales, items, estimated profit)
/// • Three tappable insight cards (stock-out / expiry / dead stock)
/// • Profit & Loss cards (today's profit + expired stock loss)
/// • Quick-action buttons (Add Product, New Sale, Sale History, Customers, Reports)
/// • Fires local notifications when risks are detected
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_loadAndNotify);
  }

  Future<void> _loadAndNotify() async {
    await ref.read(insightsProvider.notifier).load();
    if (!mounted) return;
    final summary = ref.read(insightsProvider).summary;
    if (summary == null) return;
    // Task 5 — fire local notifications when risks exist.
    final expiryCount = summary.expiryAlerts.length;
    final stockOutCount = summary.stockOutAlerts.length;
    if (expiryCount > 0) {
      await NotificationService.instance.showExpiryWarning(expiryCount);
    }
    if (stockOutCount > 0) {
      await NotificationService.instance.showStockOutWarning(stockOutCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(appLocalizationsProvider);
    final auth = ref.watch(authProvider);
    final insights = ref.watch(insightsProvider);
    final summary = insights.summary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.appName),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          const _LanguageToggle(),
          IconButton(
            tooltip: l.logout,
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, l),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(insightsProvider.notifier).load();
          final s = ref.read(insightsProvider).summary;
          if (s == null || !mounted) return;
          if (s.expiryAlerts.isNotEmpty) {
            await NotificationService.instance
                .showExpiryWarning(s.expiryAlerts.length);
          }
          if (s.stockOutAlerts.isNotEmpty) {
            await NotificationService.instance
                .showStockOutWarning(s.stockOutAlerts.length);
          }
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
          children: [
            // Error banner
            if (insights.error != null)
              _ErrorBanner(
                message: l.refreshFailed,
                retryLabel: l.retry,
                onRetry: _loadAndNotify,
              ),

            // ── Today's summary ─────────────────────────────────────────
            _TodaySummaryBanner(
              l: l,
              userName: auth.user?.name,
              summary: summary,
              isLoading: insights.isLoading && summary == null,
            ),
            const SizedBox(height: 18),

            // ── Profit & Loss insight cards ──────────────────────────────
            if (summary != null) ...[
              Row(
                children: [
                  Expanded(
                    child: _MiniInsightCard(
                      icon: Icons.trending_up_rounded,
                      label: l.todayProfit,
                      value: l.formatAmount(summary.todayEstimatedProfit),
                      color: summary.todayEstimatedProfit >= 0
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniInsightCard(
                      icon: Icons.warning_amber_rounded,
                      label: l.potentialLoss,
                      value: l.formatAmount(summary.expiredValue),
                      color: summary.expiredValue > 0
                          ? AppColors.riskCritical
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],

            // ── Smart insights (alert cards) ─────────────────────────────
            _SectionTitle(l.smartInsights),
            const SizedBox(height: 14),
            _AlertCard(
              index: 0,
              icon: Icons.error_outline_rounded,
              title: l.stockOutRisk,
              countText: summary == null
                  ? l.loading
                  : l.itemsAtRisk(summary.stockOutAlerts.length),
              gradientColors: const [Color(0xFFE53935), Color(0xFFFF7043)],
              onTap: () => _showStockOutSheet(context, l, summary),
            ),
            const SizedBox(height: 14),
            _AlertCard(
              index: 1,
              icon: Icons.schedule_rounded,
              title: l.expiryRisk,
              countText: summary == null
                  ? l.loading
                  : l.itemsExpiring(summary.expiryAlerts.length),
              valueText: (summary == null || summary.totalExpiryValueAtRisk <= 0)
                  ? null
                  : '${l.valueAtRisk}: ${l.formatAmount(summary.totalExpiryValueAtRisk)}',
              gradientColors: const [Color(0xFFFB8C00), Color(0xFFFFB74D)],
              onTap: () => _showExpirySheet(context, l, summary),
            ),
            const SizedBox(height: 14),
            _AlertCard(
              index: 2,
              icon: Icons.hourglass_bottom_rounded,
              title: l.deadStock,
              countText: summary == null
                  ? l.loading
                  : l.slowItems(summary.deadStockAlerts.length),
              valueText: (summary == null || summary.deadStockAlerts.isEmpty)
                  ? null
                  : '${l.stockValue}: ${l.formatAmount(_deadStockValue(summary))}',
              gradientColors: const [Color(0xFF1E88E5), Color(0xFF64B5F6)],
              onTap: () => _showDeadStockSheet(context, l, summary),
            ),
            const SizedBox(height: 30),

            // ── Quick actions ────────────────────────────────────────────
            _SectionTitle(l.quickActions),
            const SizedBox(height: 14),
            // Row 1: Add Product | New Sale | Sale History
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.add_circle_rounded,
                    label: l.addProduct,
                    colors: const [AppColors.primary, AppColors.primaryLight],
                    onTap: () => _push(context, const ProductFormScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.point_of_sale_rounded,
                    label: l.newSale,
                    colors: const [AppColors.accent, AppColors.accentLight],
                    onTap: () => _push(context, const CreateSaleScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.receipt_long_rounded,
                    label: l.saleHistory,
                    colors: const [Color(0xFF00897B), Color(0xFF4DB6AC)],
                    onTap: () => _push(context, const SaleHistoryScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Customers (Baki) | Reports
            Row(
              children: [
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.people_alt_rounded,
                    label: l.customers,
                    colors: const [Color(0xFF7B1FA2), Color(0xFFBA68C8)],
                    onTap: () => _push(context, const CustomerListScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionButton(
                    icon: Icons.insights_rounded,
                    label: l.viewReports,
                    colors: const [AppColors.secondary, AppColors.secondaryLight],
                    onTap: () => _push(context, const ReportScreen()),
                  ),
                ),
                const SizedBox(width: 12),
                // Spacer to keep 3-column alignment
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _deadStockValue(SmartSummary s) =>
      s.deadStockAlerts.fold<double>(0, (a, b) => a + b.stockValue);

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  Future<void> _confirmLogout(BuildContext context, AppLocalizations l) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.confirmLogoutTitle),
        content: Text(l.confirmLogoutMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l.no)),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l.yes)),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()));
  }

  // ── Bottom sheets ──────────────────────────────────────────────────────────

  void _showStockOutSheet(
      BuildContext context, AppLocalizations l, SmartSummary? summary) {
    final alerts = summary?.stockOutAlerts ?? const <StockOutAlert>[];
    _showAlertSheet(
      context: context,
      l: l,
      title: l.stockOutRisk,
      headerColor: const Color(0xFFE53935),
      headerIcon: Icons.error_outline_rounded,
      count: alerts.length,
      tiles: alerts
          .map((a) => _DetailTile(
                color: _stockOutColor(a.severity),
                title: a.productName,
                subtitle: a.severity == StockOutSeverity.outOfStock
                    ? l.outOfStock
                    : l.runsOutIn(a.daysRemaining),
                meta:
                    '${l.currentStock}: ${l.formatQty(a.currentStock, a.unit)} • ${l.suggestedRestock}: ~${l.formatQty(a.suggestedRestock, a.unit)}',
              ))
          .toList(),
    );
  }

  void _showExpirySheet(
      BuildContext context, AppLocalizations l, SmartSummary? summary) {
    final alerts = summary?.expiryAlerts ?? const <ExpiryAlert>[];
    _showAlertSheet(
      context: context,
      l: l,
      title: l.expiryRisk,
      headerColor: const Color(0xFFFB8C00),
      headerIcon: Icons.schedule_rounded,
      count: alerts.length,
      tiles: alerts
          .map((a) => _DetailTile(
                color: _expiryColor(a.severity),
                title: a.productName,
                subtitle: a.daysUntilExpiry < 0
                    ? l.expired
                    : l.expiresIn(a.daysUntilExpiry),
                meta:
                    '${l.batch}: ${a.batchNumber ?? '—'} • ${l.quantity}: ${l.formatQty(a.quantity)}',
                trailing: l.formatAmount(a.valueAtRisk),
              ))
          .toList(),
    );
  }

  void _showDeadStockSheet(
      BuildContext context, AppLocalizations l, SmartSummary? summary) {
    final alerts = summary?.deadStockAlerts ?? const <DeadStockAlert>[];
    _showAlertSheet(
      context: context,
      l: l,
      title: l.deadStock,
      headerColor: const Color(0xFF1E88E5),
      headerIcon: Icons.hourglass_bottom_rounded,
      count: alerts.length,
      tiles: alerts
          .map((a) => _DetailTile(
                color: const Color(0xFF1E88E5),
                title: a.productName,
                subtitle: l.noSalesIn30,
                meta:
                    '${l.currentStock}: ${l.formatQty(a.stockQuantity, a.unit)} • ${l.lastSale}: ${a.lastSaleDate == null ? l.neverSold : l.formatDate(a.lastSaleDate!)}',
                trailing: l.formatAmount(a.stockValue),
              ))
          .toList(),
    );
  }

  Future<void> _showAlertSheet({
    required BuildContext context,
    required AppLocalizations l,
    required String title,
    required Color headerColor,
    required IconData headerIcon,
    required int count,
    required List<Widget> tiles,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) => Container(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.78),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: headerColor, shape: BoxShape.circle),
                    child:
                        Icon(headerIcon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: headerColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(l.formatQty(count),
                        style: TextStyle(
                            color: headerColor,
                            fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(sheetContext).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (tiles.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Text(l.noAlertsHere,
                    style:
                        const TextStyle(color: AppColors.textSecondary)),
              )
            else
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                  children: [
                    for (final tile in tiles) ...[
                      tile,
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _stockOutColor(StockOutSeverity severity) {
    switch (severity) {
      case StockOutSeverity.outOfStock:
        return AppColors.riskCritical;
      case StockOutSeverity.critical:
        return AppColors.riskHigh;
      case StockOutSeverity.warning:
        return AppColors.riskMedium;
    }
  }

  Color _expiryColor(ExpirySeverity severity) {
    switch (severity) {
      case ExpirySeverity.expired:
        return AppColors.riskCritical;
      case ExpirySeverity.critical:
        return AppColors.riskHigh;
      case ExpirySeverity.warning:
        return AppColors.riskMedium;
      case ExpirySeverity.notice:
        return AppColors.riskWarning;
    }
  }
}

// =============================================================================
// Reusable widgets
// =============================================================================

class _LanguageToggle extends ConsumerWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(languageProvider).language;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg(lang == AppLanguage.bn, 'BN',
              () => ref.read(languageProvider.notifier).setLanguage(AppLanguage.bn)),
          _seg(lang == AppLanguage.en, 'EN',
              () => ref.read(languageProvider.notifier).setLanguage(AppLanguage.en)),
        ],
      ),
    );
  }

  Widget _seg(bool active, String label, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, anim) =>
              ScaleTransition(scale: anim, child: child),
          child: Container(
            key: ValueKey('$label-$active'),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? AppColors.primary : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary),
      );
}

/// Today's summary banner — sales, items sold, plus today's estimated profit.
class _TodaySummaryBanner extends StatelessWidget {
  final AppLocalizations l;
  final String? userName;
  final SmartSummary? summary;
  final bool isLoading;

  const _TodaySummaryBanner({
    required this.l,
    required this.userName,
    required this.summary,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final amount = summary?.todaySalesAmount;
    final items = summary?.todayItemsSold;
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l.welcome}, ${userName ?? ''}!',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(l.formatDate(DateTime.now()),
                        style: const TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.trending_up_rounded,
                  color: Colors.white, size: 34),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _BannerStat(
                  label: l.todaysSales,
                  value: isLoading
                      ? '...'
                      : l.formatAmount(amount ?? 0),
                ),
              ),
              Container(
                  width: 1, height: 38, color: Colors.white.withOpacity(0.3)),
              const SizedBox(width: 16),
              Expanded(
                child: _BannerStat(
                  label: l.itemsSold,
                  value: isLoading ? '...' : l.formatQty(items ?? 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BannerStat extends StatelessWidget {
  final String label;
  final String value;
  const _BannerStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
        ],
      );
}

/// Small 2-column insight card for profit & loss figures.
class _MiniInsightCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniInsightCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Color(0x12000000),
                blurRadius: 10,
                offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      );
}

class _AlertCard extends StatelessWidget {
  final int index;
  final IconData icon;
  final String title;
  final String countText;
  final String? valueText;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _AlertCard({
    required this.index,
    required this.icon,
    required this.title,
    required this.countText,
    this.valueText,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.94, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shadowColor: gradientColors.first.withOpacity(0.2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          child: InkWell(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    gradientColors.first.withOpacity(0.12),
                    gradientColors.last.withOpacity(0.04),
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: gradientColors),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: gradientColors.first.withOpacity(0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(countText,
                            style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14)),
                        if (valueText != null) ...[
                          const SizedBox(height: 4),
                          Text(valueText!,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: gradientColors.first)),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: gradientColors.first.withOpacity(0.5)),
                ],
              ),
            ),
          ),
        ),
      );
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.95, end: 1),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: colors.first.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: Colors.white, size: 30),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;

  const _ErrorBanner(
      {required this.message,
      required this.retryLabel,
      required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 13)),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(retryLabel,
                  style: const TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
}

class _DetailTile extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final String? meta;
  final String? trailing;

  const _DetailTile({
    required this.color,
    required this.title,
    required this.subtitle,
    this.meta,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(3)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(color: color, fontSize: 14)),
                    if (meta != null) ...[
                      const SizedBox(height: 2),
                      Text(meta!,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(trailing!,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                ),
            ],
          ),
        ),
      );
}
