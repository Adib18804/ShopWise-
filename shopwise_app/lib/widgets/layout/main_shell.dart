import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../features/auth/screens/welcome_screen.dart';
import '../../features/customers/screens/customer_list_screen.dart';
import '../../features/dashboard/screens/admin_feedback_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/dashboard/screens/feedback_screen.dart';
import '../../features/products/screens/products_screen.dart';
import '../../features/reports/screens/report_screen.dart';
import '../../features/sales/screens/create_sale_screen.dart';
import '../../features/sales/screens/sale_history_screen.dart';
import '../../models/shop_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feedback_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/shop_provider.dart';
import '../../services/account_deletion_service.dart';

/// Riverpod provider that tracks the current shell tab index (0–4, skipping 2).
final _shellIndexProvider = StateProvider<int>((ref) => 0);
const privacyPolicyUrl = 'https://adib18804.github.io/ShopWise-/';
const termsConditionsUrl = 'https://adib18804.github.io/ShopWise-/terms.html';

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
            ).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
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
    return DefaultTextStyle(
      style: DefaultTextStyle.of(context).style,
      softWrap: true,
      overflow: TextOverflow.ellipsis,
      child: Scaffold(
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
      ),
    );
  }

  // ── "More" bottom sheet ────────────────────────────────────────────────────

  void _showMoreSheet() {
    final l = ref.read(appLocalizationsProvider);
    final isLibrary = ref.read(shopTypeProvider) == ShopType.library;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black38,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MoreSheet(
        l: l,
        isLibrary: isLibrary,
        onLogout: () => _logout(context, l),
        onDeleteAccount: () => _deleteAccount(context, l),
        onPrivacyPolicy: () => _openPrivacyPolicy(context, l),
        onTermsConditions: () => _openTermsConditions(context, l),
      ),
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
            child: Text(l.no),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dlg).pop(true),
            child: Text(l.yes),
          ),
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

  Future<void> _openPrivacyPolicy(
    BuildContext context,
    AppLocalizations l,
  ) async {
    final uri = Uri.parse(privacyPolicyUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.isBn
                ? 'গোপনীয়তা নীতি খোলা যায়নি।'
                : 'Could not open the Privacy Policy.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _openTermsConditions(
    BuildContext context,
    AppLocalizations l,
  ) async {
    final opened = await launchUrl(
      Uri.parse(termsConditionsUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l.isBn
                ? 'শর্তাবলী খোলা যায়নি।'
                : 'Could not open Terms & Conditions.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _deleteAccount(
    BuildContext context,
    AppLocalizations l,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.error,
          size: 34,
        ),
        title: Text(l.isBn ? 'অ্যাকাউন্ট মুছে ফেলবেন?' : 'Delete account?'),
        content: Text(
          l.isBn
              ? 'এতে আপনার অ্যাকাউন্ট, দোকান, পণ্য, স্টক ব্যাচ, বিক্রয়, ক্যাটাগরি এবং গ্রাহক/সদস্যের তথ্য স্থায়ীভাবে মুছে যাবে। এই কাজটি আর ফিরিয়ে নেওয়া যাবে না।'
              : 'This permanently deletes your account, shop, products, stock batches, sales, categories, and customer/member data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.isBn ? 'বাতিল' : 'Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            icon: const Icon(Icons.delete_forever_rounded),
            label: Text(l.isBn ? 'সব মুছে ফেলুন' : 'Delete everything'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final passwordController = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.isBn ? 'পরিচয় নিশ্চিত করুন' : 'Confirm your identity'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.isBn ? 'বর্তমান পাসওয়ার্ড' : 'Current password',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.isBn ? 'বাতিল' : 'Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () =>
                Navigator.of(dialogContext).pop(passwordController.text),
            child: Text(l.isBn ? 'চালিয়ে যান' : 'Continue'),
          ),
        ],
      ),
    );
    passwordController.dispose();
    if (password == null || password.isEmpty || !context.mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      await AccountDeletionService().deleteCurrentAccount(password: password);
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close progress dialog
      await ref.read(authProvider.notifier).logout();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const WelcomeScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // close progress dialog
      final detail = error is FirebaseAuthException
          ? (error.message ?? error.code)
          : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l.isBn ? 'অ্যাকাউন্ট মুছতে সমস্যা হয়েছে' : 'Account deletion failed'}: $detail',
          ),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }
}

// =============================================================================
// Bottom bar
// =============================================================================

class _ShopWiseBottomBar extends StatelessWidget {
  const _ShopWiseBottomBar({required this.currentSlot, required this.onTap});
  final int currentSlot;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: compact ? 58 : 64,
                child: Row(
                  children: [
                    // Slot 0 — Home
                    _NavItem(
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: 'Home',
                      active: currentSlot == 0,
                      compact: compact,
                      onTap: () => onTap(0),
                    ),
                    // Slot 1 — Stock
                    _NavItem(
                      icon: Icons.inventory_2_outlined,
                      activeIcon: Icons.inventory_2_rounded,
                      label: 'Stock',
                      active: currentSlot == 1,
                      compact: compact,
                      onTap: () => onTap(1),
                    ),
                    // Slot 2 — FAB spacer
                    const Expanded(child: SizedBox()),
                    // Slot 3 — Insights
                    _NavItem(
                      icon: Icons.bar_chart_outlined,
                      activeIcon: Icons.bar_chart_rounded,
                      label: 'Insights',
                      active: currentSlot == 3,
                      compact: compact,
                      onTap: () => onTap(3),
                    ),
                    // Slot 4 — More
                    _NavItem(
                      icon: Icons.menu_rounded,
                      activeIcon: Icons.menu_rounded,
                      label: 'More',
                      active: currentSlot == 4,
                      compact: compact,
                      onTap: () => onTap(4),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('currentSlot', currentSlot));
    properties.add(ObjectFlagProperty<ValueChanged<int>>.has('onTap', onTap));
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.compact,
    required this.onTap,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.textDisabled;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.primary.withValues(alpha: 0.08),
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
                  fontSize: compact ? 9 : 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(DiagnosticsProperty<IconData>('activeIcon', activeIcon));
    properties.add(StringProperty('label', label));
    properties.add(DiagnosticsProperty<bool>('active', active));
    properties.add(DiagnosticsProperty<bool>('compact', compact));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
  }
}

// =============================================================================
// Floating Action Button (centre-docked, orange)
// =============================================================================

class _ShopWiseFAB extends StatelessWidget {
  const _ShopWiseFAB({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        child: Builder(builder: (context) {
          final size = MediaQuery.sizeOf(context).width < 360 ? 48.0 : 56.0;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child:
                Icon(Icons.add_rounded, color: Colors.white, size: size * 0.54),
          );
        }),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
  }
}

// =============================================================================
// "More" bottom-sheet contents
// =============================================================================

class _MoreSheet extends ConsumerWidget {
  const _MoreSheet({
    required this.l,
    required this.isLibrary,
    required this.onLogout,
    required this.onDeleteAccount,
    required this.onPrivacyPolicy,
    required this.onTermsConditions,
  });
  final AppLocalizations l;
  final bool isLibrary;
  final VoidCallback onLogout;
  final VoidCallback onDeleteAccount;
  final VoidCallback onPrivacyPolicy;
  final VoidCallback onTermsConditions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isFirebaseAdminProvider).asData?.value ?? false;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              top: 12,
              bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
            ),
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
                  label: isLibrary
                      ? (l.isBn ? 'ইস্যু ইতিহাস' : 'Issue History')
                      : l.saleHistory,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SaleHistoryScreen(),
                      ),
                    );
                  },
                ),
                _SheetTile(
                  icon: Icons.people_alt_rounded,
                  label:
                      isLibrary ? (l.isBn ? 'সদস্য' : 'Members') : l.customers,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CustomerListScreen(),
                      ),
                    );
                  },
                ),
                _SheetTile(
                  icon: Icons.support_agent_rounded,
                  label: l.isBn ? 'সহায়তা ও মতামত' : 'Help & Support',
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const FeedbackScreen(),
                      ),
                    );
                  },
                ),
                if (isAdmin)
                  _SheetTile(
                    icon: Icons.admin_panel_settings_rounded,
                    label: l.isBn ? 'অ্যাডমিন প্যানেল' : 'Admin Panel',
                    color: AppColors.accent,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const AdminFeedbackScreen(),
                        ),
                      );
                    },
                  ),
                const Divider(height: 16, indent: 56, endIndent: 16),
                _SheetTile(
                  icon: Icons.privacy_tip_outlined,
                  label: l.isBn ? 'গোপনীয়তা নীতি' : 'Privacy Policy',
                  onTap: () {
                    Navigator.of(context).pop();
                    onPrivacyPolicy();
                  },
                ),
                _SheetTile(
                  icon: Icons.description_outlined,
                  label: l.isBn ? 'শর্তাবলী' : 'Terms & Conditions',
                  onTap: () {
                    Navigator.of(context).pop();
                    onTermsConditions();
                  },
                ),
                _SheetTile(
                  icon: Icons.delete_forever_outlined,
                  label: l.isBn ? 'অ্যাকাউন্ট মুছুন' : 'Delete Account',
                  color: AppColors.error,
                  onTap: () {
                    Navigator.of(context).pop();
                    onDeleteAccount();
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
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
    properties.add(DiagnosticsProperty<bool>('isLibrary', isLibrary));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onLogout', onLogout));
    properties.add(ObjectFlagProperty<VoidCallback>.has(
        'onDeleteAccount', onDeleteAccount));
    properties.add(ObjectFlagProperty<VoidCallback>.has(
        'onPrivacyPolicy', onPrivacyPolicy));
    properties.add(ObjectFlagProperty<VoidCallback>.has(
        'onTermsConditions', onTermsConditions));
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.primary, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: c,
        ),
      ),
      onTap: onTap,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(StringProperty('label', label));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
    properties.add(ColorProperty('color', color));
  }
}

// "More" tab placeholder — the real content is the sheet, so this is never
// actually visible, but PageView needs 4 children.
class _MorePlaceholder extends StatelessWidget {
  const _MorePlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
