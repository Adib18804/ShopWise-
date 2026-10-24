import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/reports_provider.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../categories/screens/categories_screen.dart';
import '../../products/screens/products_screen.dart';
import '../../reports/screens/report_screen.dart';
import '../../sales/screens/create_sale_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(reportsProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final reportState = ref.watch(reportsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ShopWise'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: '\u09b2\u0997\u0986\u0989\u099f',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          Text(
            '\u09b8\u09cd\u09ac\u09be\u0997\u09a4\u09ae, ${user?.name ?? '\u09ac\u09cd\u09af\u09ac\u09b9\u09be\u09b0\u0995\u09be\u09b0\u09c0'}!',
            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(user?.email ?? '',
              style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 18),
          _TodaySalesBanner(
            amount: reportState.summary?.totalSalesAmount,
            isLoading: reportState.isLoading,
            hasError: reportState.error != null,
            onRetry: () => ref.read(reportsProvider.notifier).load(),
          ),
          const SizedBox(height: 24),
          const Text(
            '\u09a6\u09cd\u09b0\u09c1\u09a4 \u0995\u09be\u099c',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _DashboardCard(
                icon: Icons.category_rounded,
                label: '\u0995\u09cd\u09af\u09be\u099f\u09be\u0997\u09b0\u09bf',
                colors: const [Color(0xFF2196F3), Color(0xFF64B5F6)],
                onTap: () => _push(context, const CategoriesScreen()),
              ),
              _DashboardCard(
                icon: Icons.inventory_2_rounded,
                label: '\u09aa\u09a3\u09cd\u09af',
                colors: const [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                onTap: () => _push(context, const ProductsScreen()),
              ),
              _DashboardCard(
                icon: Icons.point_of_sale_rounded,
                label: '\u09ac\u09bf\u0995\u09cd\u09b0\u09df',
                colors: const [Color(0xFFFF9800), Color(0xFFFFB74D)],
                onTap: () => _push(context, const CreateSaleScreen()),
              ),
              _DashboardCard(
                icon: Icons.insights_rounded,
                label: '\u09b0\u09bf\u09aa\u09cb\u09b0\u09cd\u099f',
                colors: const [Color(0xFF1976D2), Color(0xFF64B5F6)],
                onTap: () => _push(context, const ReportScreen()),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  static Future<void> _confirmLogout(
      BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('\u09b2\u0997\u0986\u0989\u099f'),
        content: const Text(
            '\u0986\u09aa\u09a8\u09bf \u0995\u09bf \u09b2\u0997\u0986\u0989\u099f \u0995\u09b0\u09a4\u09c7 \u099a\u09be\u09a8?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\u09a8\u09be')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('\u09b9\u09cd\u09af\u09be\u0981')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()));
  }
}

class _TodaySalesBanner extends StatelessWidget {
  final double? amount;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;

  const _TodaySalesBanner(
      {required this.amount,
      required this.isLoading,
      required this.hasError,
      required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 8))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      '\u0986\u099c\u0995\u09c7\u09b0 \u09ae\u09cb\u099f \u09ac\u09bf\u0995\u09cd\u09b0\u09bf',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    amount == null
                        ? (hasError
                            ? '\u09a4\u09a5\u09cd\u09af \u09aa\u09be\u0993\u09df\u09be \u09af\u09be\u09df\u09a8\u09bf'
                            : '\u09b2\u09cb\u09a1 \u09b9\u099a\u09cd\u099b\u09c7...')
                        : '\u09F3${amount!.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox.square(
                  dimension: 25,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
            else if (hasError)
              IconButton(
                  onPressed: onRetry,
                  color: Colors.white,
                  tooltip:
                      '\u0986\u09ac\u09be\u09b0 \u099a\u09c7\u09b7\u09cd\u099f\u09be',
                  icon: const Icon(Icons.refresh))
            else
              const Icon(Icons.trending_up_rounded,
                  color: Colors.white, size: 36),
          ],
        ),
      );
}

class _DashboardCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const _DashboardCard(
      {required this.icon,
      required this.label,
      required this.colors,
      required this.onTap});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.96, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Card(
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shadowColor: colors.first.withOpacity(0.18),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: InkWell(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                    colors.first.withOpacity(0.14),
                    colors.last.withOpacity(0.05)
                  ])),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: colors),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: colors.first.withOpacity(0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 5))
                        ]),
                    child: Icon(icon, color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 12),
                  Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ],
              ),
            ),
          ),
        ),
      );
}
