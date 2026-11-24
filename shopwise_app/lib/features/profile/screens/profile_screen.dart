import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/shop_model.dart';
import '../../../models/user_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/feedback_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';

/// Read-only account and shop profile shared by regular users and admins.
/// Details come from the existing authenticated providers, so only the signed-
/// in user's own Firestore-backed data is displayed here.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = ref.watch(appLocalizationsProvider);
    final auth = ref.watch(authProvider);
    final shopState = ref.watch(shopProvider);
    final isAdmin = ref.watch(isFirebaseAdminProvider).asData?.value ?? false;
    final user = auth.user;
    final shop = shopState.shop;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.isBn ? 'প্রোফাইল' : 'Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: l.isBn ? 'তথ্য রিফ্রেশ করুন' : 'Refresh profile',
            onPressed: () async {
              await Future.wait<void>([
                ref.read(authProvider.notifier).refreshUser(),
                ref.read(shopProvider.notifier).loadShop(),
              ]);
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: auth.isLoading && user == null
          ? const Center(child: CircularProgressIndicator())
          : user == null
              ? _EmptyProfile(isBn: l.isBn)
              : RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait<void>([
                      ref.read(authProvider.notifier).refreshUser(),
                      ref.read(shopProvider.notifier).loadShop(),
                    ]);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    children: [
                      _ProfileHeader(
                        user: user,
                        isAdmin: isAdmin,
                        isBn: l.isBn,
                      ),
                      const SizedBox(height: 18),
                      _SectionCard(
                        title: l.isBn ? 'ব্যক্তিগত তথ্য' : 'Personal details',
                        icon: Icons.person_outline_rounded,
                        children: [
                          _ProfileRow(
                            icon: Icons.badge_outlined,
                            label: l.isBn ? 'নাম' : 'Name',
                            value: _value(user.name),
                          ),
                          _ProfileRow(
                            icon: Icons.email_outlined,
                            label: l.isBn ? 'ইমেইল' : 'Email',
                            value: _value(user.email),
                          ),
                          _ProfileRow(
                            icon: Icons.phone_outlined,
                            label: l.isBn ? 'ফোন' : 'Phone',
                            value: _value(user.phone),
                            isLast: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _SectionCard(
                        title: l.isBn ? 'দোকানের তথ্য' : 'Shop details',
                        icon: Icons.storefront_outlined,
                        trailing: shopState.isLoading
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : null,
                        children: shop == null
                            ? [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    6,
                                    16,
                                    16,
                                  ),
                                  child: Text(
                                    l.isBn
                                        ? 'দোকানের তথ্য পাওয়া যায়নি। নিচে টেনে রিফ্রেশ করুন।'
                                        : 'Shop details are unavailable. Pull down to refresh.',
                                    style: const TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ]
                            : [
                                _ProfileRow(
                                  icon: Icons.store_outlined,
                                  label: l.isBn ? 'দোকানের নাম' : 'Shop name',
                                  value: _value(shop.shopName),
                                ),
                                _ProfileRow(
                                  icon: Icons.category_outlined,
                                  label: l.isBn ? 'দোকানের ধরন' : 'Shop type',
                                  value: _shopTypeLabel(shop.shopType, l.isBn),
                                ),
                                _ProfileRow(
                                  icon: Icons.phone_in_talk_outlined,
                                  label: l.isBn ? 'দোকানের ফোন' : 'Shop phone',
                                  value: _value(shop.phone),
                                ),
                                _ProfileRow(
                                  icon: Icons.location_on_outlined,
                                  label: l.isBn ? 'ঠিকানা' : 'Address',
                                  value: _value(shop.address),
                                  isLast: true,
                                ),
                              ],
                      ),
                      if (shopState.error != null && shop == null) ...[
                        const SizedBox(height: 10),
                        Text(
                          shopState.error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _AccountNote(isBn: l.isBn),
                    ],
                  ),
                ),
    );
  }

  static String _value(String value) => value.trim().isEmpty ? '—' : value;

  static String _shopTypeLabel(ShopType type, bool isBn) => switch (type) {
        ShopType.general => isBn ? 'জেনারেল স্টোর' : 'General Store',
        ShopType.pharmacy => isBn ? 'ফার্মেসি' : 'Pharmacy',
        ShopType.stationery => isBn ? 'স্টেশনারি' : 'Stationery',
        ShopType.library => isBn ? 'লাইব্রেরি' : 'Library',
      };
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.user,
    required this.isAdmin,
    required this.isBn,
  });

  final UserModel user;
  final bool isAdmin;
  final bool isBn;

  @override
  Widget build(BuildContext context) {
    final displayName = user.name.trim().isEmpty
        ? (isBn ? 'ShopWise ব্যবহারকারী' : 'ShopWise user')
        : user.name.trim();
    final initial = displayName.characters.first.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.cardShadow,
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 13,
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      child: Text(
                        isBn ? 'অ্যাডমিন' : 'Admin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            ...children,
          ],
        ),
      );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 105,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      value,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isLast)
              const Divider(height: 1, indent: 32, color: AppColors.border),
          ],
        ),
      );
}

class _AccountNote extends StatelessWidget {
  const _AccountNote({required this.isBn});

  final bool isBn;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isBn
                    ? 'এই তথ্য শুধু আপনার সাইন-ইন করা অ্যাকাউন্টের জন্য দেখানো হয়।'
                    : 'These details are shown for your signed-in account only.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
}

class _EmptyProfile extends StatelessWidget {
  const _EmptyProfile({required this.isBn});

  final bool isBn;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 64,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                isBn
                    ? 'প্রোফাইল তথ্য পাওয়া যায়নি। আবার লগইন করুন।'
                    : 'Profile information is unavailable. Please sign in again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
}
