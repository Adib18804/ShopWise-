import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../features/auth/widgets/auth_button.dart';
import '../../../features/auth/widgets/auth_text_field.dart';
import '../../../models/shop_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';
import '../../../widgets/layout/main_shell.dart';

/// Shop setup screen
class ShopSetupScreen extends ConsumerStatefulWidget {
  const ShopSetupScreen({super.key});

  @override
  ConsumerState<ShopSetupScreen> createState() => _ShopSetupScreenState();
}

class _ShopSetupScreenState extends ConsumerState<ShopSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedCurrency = 'BDT';
  ShopType _selectedShopType = ShopType.general;

  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final success = await ref.read(shopProvider.notifier).createShop(
          shopName: _shopNameController.text.trim(),
          address: _addressController.text.trim(),
          phone: _phoneController.text.trim(),
          currency: _selectedCurrency,
          shopType: _selectedShopType,
        );

    if (!mounted) return;

    if (success) {
      // Refresh user data to update has_shop status
      await ref.read(authProvider.notifier).refreshUser();

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('দোকান সফলভাবে তৈরি হয়েছে'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const ShopWiseShell(),
        ),
      );
    } else {
      // Show error
      final error = ref.read(shopProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'দোকান তৈরি করতে ব্যর্থ'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopState = ref.watch(shopProvider);
    final isBn = ref.watch(appLocalizationsProvider).isBn;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('দোকান সেটআপ'),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome message
                const Text(
                  'আপনার দোকানের তথ্য দিন',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'এই তথ্য আপনার দোকান পরিচালনায় সাহায্য করবে',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  isBn ? 'আপনার ব্যবসার ধরন নির্বাচন করুন *' : 'Select your business type *',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ...ShopType.values.map((type) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ShopTypeOption(
                        type: type,
                        selected: _selectedShopType == type,
                        enabled: !shopState.isLoading,
                        isBn: isBn,
                        onTap: () => setState(() => _selectedShopType = type),
                      ),
                    ),),
                const SizedBox(height: 20),

                // Shop name field
                AuthTextField(
                  controller: _shopNameController,
                  label: 'দোকানের নাম *',
                  hint: 'যেমন: রহিম স্টোর',
                  prefixIcon: const Icon(Icons.store),
                  enabled: !shopState.isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'দোকানের নাম প্রয়োজন';
                    }
                    if (value.trim().length < 2) {
                      return 'দোকানের নাম কমপক্ষে ২ অক্ষর হতে হবে';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Address field
                AuthTextField(
                  controller: _addressController,
                  label: 'ঠিকানা *',
                  hint: 'দোকানের সম্পূর্ণ ঠিকানা',
                  keyboardType: TextInputType.streetAddress,
                  prefixIcon: const Icon(Icons.location_on),
                  enabled: !shopState.isLoading,
                  maxLines: 2,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'ঠিকানা প্রয়োজন';
                    }
                    if (value.trim().length < 5) {
                      return 'ঠিকানা কমপক্ষে ৫ অক্ষর হতে হবে';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Phone field
                AuthTextField(
                  controller: _phoneController,
                  label: 'ফোন নম্বর *',
                  hint: '01XXXXXXXXX',
                  keyboardType: TextInputType.phone,
                  prefixIcon: const Icon(Icons.phone),
                  enabled: !shopState.isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'ফোন নম্বর প্রয়োজন';
                    }
                    // Bangladesh phone number validation
                    if (!RegExp(r'^01[3-9]\d{8}$').hasMatch(value.trim())) {
                      return 'সঠিক বাংলাদেশী ফোন নম্বর লিখুন';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Currency selection
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'মুদ্রা *',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCurrency,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down),
                          items: const [
                            DropdownMenuItem(
                              value: 'BDT',
                              child: Row(
                                children: [
                                  Icon(Icons.currency_exchange),
                                  SizedBox(width: 12),
                                  Text('BDT (৳) - বাংলাদেশী টাকা'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'USD',
                              child: Row(
                                children: [
                                  Icon(Icons.attach_money),
                                  SizedBox(width: 12),
                                  Text(r'USD ($) - US Dollar'),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'EUR',
                              child: Row(
                                children: [
                                  Icon(Icons.euro),
                                  SizedBox(width: 12),
                                  Text('EUR (€) - Euro'),
                                ],
                              ),
                            ),
                          ],
                          onChanged: shopState.isLoading
                              ? null
                              : (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCurrency = value;
                                    });
                                  }
                                },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Info box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'আপনি পরে এই তথ্য পরিবর্তন করতে পারবেন',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Submit button
                AuthButton(
                  text: 'দোকান তৈরি করুন',
                  onPressed: _handleSubmit,
                  isLoading: shopState.isLoading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopTypeOption extends StatelessWidget {

  const _ShopTypeOption({
    required this.type,
    required this.selected,
    required this.enabled,
    required this.isBn,
    required this.onTap,
  });
  final ShopType type;
  final bool selected;
  final bool enabled;
  final bool isBn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (bn, en, icon, detailBn, detailEn) = switch (type) {
      ShopType.general => ('জেনারেল স্টোর', 'General Store', Icons.storefront, 'মুদি ও দৈনন্দিন পণ্য', 'Groceries and daily essentials'),
      ShopType.pharmacy => ('ফার্মেসি', 'Pharmacy', Icons.local_pharmacy, 'ওষুধ, ব্যাচ ও মেয়াদ ট্র্যাকিং', 'Medicine, batch and expiry tracking'),
      ShopType.stationery => ('স্টেশনারি', 'Stationery', Icons.edit_note, 'খাতা, কলম ও অফিস সামগ্রী', 'Books, pens and office supplies'),
      ShopType.library => ('লাইব্রেরি', 'Library', Icons.local_library, 'বই ইস্যু ও ফেরত ব্যবস্থাপনা', 'Book issue and return tracking'),
    };

    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.grey.shade300,
              width: selected ? 1.7 : 1,
            ),
          ),
          child: Row(children: [
            Icon(icon, color: AppColors.primary, size: 25),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isBn ? bn : en, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(isBn ? detailBn : detailEn,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),),
              ],),
            ),
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.primary : Colors.grey,),
          ],),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<ShopType>('type', type));
    properties.add(DiagnosticsProperty<bool>('selected', selected));
    properties.add(DiagnosticsProperty<bool>('enabled', enabled));
    properties.add(DiagnosticsProperty<bool>('isBn', isBn));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
  }
}
