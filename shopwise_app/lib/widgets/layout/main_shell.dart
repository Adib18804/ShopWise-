import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/customers/screens/customer_list_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/products/screens/products_screen.dart';
import '../../features/reports/screens/report_screen.dart';
import '../../features/sales/screens/create_sale_screen.dart';
import '../../features/sales/screens/sale_history_screen.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';

/// Riverpod provider that tracks the current shell tab index (0–4, skipping 2).
final _shellIndexProvider = StateProvider<int>((ref) => 0);

/// Root navigation shell used after the user is authenticated and has a shop.
///
/// Layout: 5-slot bottom bar — Home · Stock · **+(FAB)** · Insights · More.
///   Tab 0 → Home (Dashboard)
///   Tab 1 → Stock (Products)
///   Tab 2 → FAB (opens Create Sale as a modal route, not a tab)
///   Tab 3 → Insights / Reports
///   Tab 4 → More (slide-up drawer: Sale History, Customers, Logout)
///
/// The floating orange FAB is built as a custom BottomAppBar notch so it sits
/// centred above the bar with a raised circular shape.
class ShopWiseShell extends ConsumerStatefulWidget {
  const ShopWiseShell({super.key});

  @override
  ConsumerState<ShopWiseShell> createState() => _ShopWiseShellState();
}

class _ShopWiseShellState extends ConsumerState<ShopWiseShell>
    with TickerProviderStateMixin {
  // Page controller for animated tab switching.
  late final PageController _pageController;

  // Tap-index → page-index mapping (FAB slot 2 has no page).
  static const List<int?> _slotToPage = [0, 1, null, 2, 3];
  static const List<int> _pageToSlot = [0, 1, 3, 4];

  // The actual screens (4 pages — no page for the FAB slot).
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pages = const [
      DashboardScreen(),
      ProductsScreen(),
      ReportScreen(),
      _MorePlaceholder(), // "More" tab — replaces with drawer content
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int get _currentSlot => ref.read(_shellIndexProvider);

  void _onSlotTap(int slot) {
    if (slot == 2) {
      // FAB — open Create Sale as a full-screen modal.
      Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, anim, __) => const CreateSaleScreen(),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      );
      return;
    }
    if (slot == 4) {
      // "More" — slide up the More sheet instead of navigating.
      _showMoreSheet();
      return;
    }
    final pageIndex = _slotToPage[slot];
    if (pageIndex == null) return;
    ref.read(_shellIndexProvider.notifier).state = slot;
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSlot = ref.watch(_shellIndexProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      // PageView so swipe between tabs works naturally.
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(), // nav-only switching
        children: _pages,
        onPageChanged: (page) {
          ref.read(_shellIndexProvider.notifier).state = _pageToSlot[page];
        },
      ),
      bottomNavigationBar: _ShopWiseBottomBar(
        currentSlot: currentSlot,
        onTap: _onSlotTap,
      ),
      floatingActionButton: _ShopWiseFAB(onTap: () => _onSlotTap(2)),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ── "More" bottom sheet ────────────────────────────────────────────────────

  void _showMoreSheet() {
    final l = ref.read(appLocalizationsProvider);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      builder: (_) => _MoreSheet(l: l, onLogout: () => _logout(context, l)),
    );
  }

  Future<void> _logout(BuildContext context, AppLocalizations l) async {
    Navigator.of(context).pop(); // close sheet
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: Text(l.confirmLogoutTitle),
        content: Text(l.confirmLogoutMessage),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dlg).pop(false),
              child: Text(l.no)),
          FilledButton(
              onPressed: () => Navigator.of(dlg).pop(true),
              child: Text(l.yes)),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }
}

// =============================================================================
// Bottom bar
// =============================================================================

class _ShopWiseBottomBar extends StatelessWidget {
  final int currentSlot;
  final ValueChanged<int> onTap;

  const _ShopWiseBottomBar({required this.currentSlot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // Slot 0 — Home
              _NavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Home',
                  active: currentSlot == 0,
                  onTap: () => onTap(0)),
              // Slot 1 — Stock
              _NavItem(
                  icon: Icons.inventory_2_outlined,
                  activeIcon: Icons.inventory_2_rounded,
                  label: 'Stock',
                  active: currentSlot == 1,
                  onTap: () => onTap(1)),
              // Slot 2 — FAB spacer
              const Expanded(child: SizedBox()),
              // Slot 3 — Insights
              _NavItem(
                  icon: Icons.bar_chart_outlined,
                  activeIcon: Icons.bar_chart_rounded,
                  label: 'Insights',
                  active: currentSlot == 3,
                  onTap: () => onTap(3)),
              // Slot 4 — More
              _NavItem(
                  icon: Icons.menu_rounded,
                  activeIcon: Icons.menu_rounded,
                  label: 'More',
                  active: currentSlot == 4,
                  onTap: () => onTap(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textDisabled;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withOpacity(0.08),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: child,
                ),
                child: Icon(
                  active ? activeIcon : icon,
                  key: ValueKey('$label-$active'),
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Floating Action Button (centre-docked, orange)
// =============================================================================

class _ShopWiseFAB extends StatelessWidget {
  final VoidCallback onTap;
  const _ShopWiseFAB({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }
}

// =============================================================================
// "More" bottom-sheet contents
// =============================================================================

class _MoreSheet extends StatelessWidget {
  final AppLocalizations l;
  final VoidCallback onLogout;

  const _MoreSheet({required this.l, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          _SheetTile(
            icon: Icons.receipt_long_rounded,
            label: l.saleHistory,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const SaleHistoryScreen()));
            },
          ),
          _SheetTile(
            icon: Icons.people_alt_rounded,
            label: l.customers,
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => const CustomerListScreen()));
            },
          ),
          const Divider(height: 16, indent: 56, endIndent: 16),
          _SheetTile(
            icon: Icons.logout_rounded,
            label: l.logout,
            color: AppColors.error,
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primary, size: 22),
      title: Text(label,
          style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w500, color: c)),
      onTap: onTap,
    );
  }
}

// "More" tab placeholder — the real content is the sheet, so this is never
// actually visible, but PageView needs 4 children.
class _MorePlaceholder extends StatelessWidget {
  const _MorePlaceholder();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand();
}
