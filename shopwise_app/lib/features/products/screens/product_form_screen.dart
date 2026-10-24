import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../models/product_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../features/auth/widgets/auth_text_field.dart';
import '../../../features/auth/widgets/auth_button.dart';

/// Product form screen (add/edit)
class ProductFormScreen extends ConsumerStatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({super.key, this.product});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _purchasePriceController = TextEditingController();
  final _minimumStockController = TextEditingController();
  final _targetStockDaysController = TextEditingController();
  
  int? _selectedCategoryId;
  String _selectedUnit = 'piece';
  bool _isSubmitting = false;

  final List<Map<String, String>> _units = [
    {'value': 'piece', 'label': 'টি'},
    {'value': 'kg', 'label': 'কেজি'},
    {'value': 'liter', 'label': 'লিটার'},
    {'value': 'packet', 'label': 'প্যাকেট'},
    {'value': 'box', 'label': 'বক্স'},
    {'value': 'dozen', 'label': 'ডজন'},
  ];

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    // Load categories
    Future.microtask(() => ref.read(categoryProvider.notifier).loadCategories());
    
    if (isEditing) {
      _nameController.text = widget.product!.name;
      _skuController.text = widget.product!.sku ?? '';
      _barcodeController.text = widget.product!.barcode ?? '';
      _selectedCategoryId = widget.product!.categoryId;
      _selectedUnit = widget.product!.unit;
      _sellingPriceController.text = widget.product!.sellingPrice.toString();
      _purchasePriceController.text = widget.product!.defaultPurchasePrice.toString();
      _minimumStockController.text = widget.product!.minimumStock.toString();
      _targetStockDaysController.text = widget.product!.targetStockDays.toString();
    } else {
      _sellingPriceController.text = '0';
      _purchasePriceController.text = '0';
      _minimumStockController.text = '0';
      _targetStockDaysController.text = '7';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _sellingPriceController.dispose();
    _purchasePriceController.dispose();
    _minimumStockController.dispose();
    _targetStockDaysController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ক্যাটাগরি নির্বাচন করুন'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final success = isEditing
        ? await ref.read(productProvider.notifier).updateProduct(
              id: widget.product!.id,
              categoryId: _selectedCategoryId,
              name: _nameController.text.trim(),
              sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
              barcode: _barcodeController.text.trim().isEmpty
                  ? null
                  : _barcodeController.text.trim(),
              unit: _selectedUnit,
              sellingPrice: double.parse(_sellingPriceController.text),
              defaultPurchasePrice: double.parse(_purchasePriceController.text),
              minimumStock: double.parse(_minimumStockController.text),
              targetStockDays: int.parse(_targetStockDaysController.text),
            )
        : await ref.read(productProvider.notifier).createProduct(
              categoryId: _selectedCategoryId!,
              name: _nameController.text.trim(),
              sku: _skuController.text.trim().isEmpty ? null : _skuController.text.trim(),
              barcode: _barcodeController.text.trim().isEmpty
                  ? null
                  : _barcodeController.text.trim(),
              unit: _selectedUnit,
              sellingPrice: double.parse(_sellingPriceController.text),
              defaultPurchasePrice: double.parse(_purchasePriceController.text),
              minimumStock: double.parse(_minimumStockController.text),
              targetStockDays: int.parse(_targetStockDaysController.text),
            );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final error = ref.read(productProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'অপারেশন ব্যর্থ'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoryState = ref.watch(categoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'পণ্য সম্পাদনা' : 'নতুন পণ্য'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              AuthTextField(
                controller: _nameController,
                label: 'পণ্যের নাম *',
                hint: 'যেমন: দুধ, চাল',
                keyboardType: TextInputType.text,
                prefixIcon: const Icon(Icons.inventory_2),
                enabled: !_isSubmitting,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'পণ্যের নাম প্রয়োজন';
                  }
                  if (value.trim().length < 2) {
                    return 'পণ্যের নাম কমপক্ষে ২ অক্ষর হতে হবে';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ক্যাটাগরি *',
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
                      color: _isSubmitting ? Colors.grey[100] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedCategoryId,
                        isExpanded: true,
                        hint: const Text('ক্যাটাগরি নির্বাচন করুন'),
                        icon: const Icon(Icons.arrow_drop_down),
                        items: categoryState.categories.map((category) {
                          return DropdownMenuItem<int>(
                            value: category.id,
                            child: Text(category.name),
                          );
                        }).toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                setState(() => _selectedCategoryId = value);
                              },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // SKU and barcode fields
              AuthTextField(
                controller: _skuController,
                label: 'SKU (ঐচ্ছিক)',
                hint: 'পণ্যের কোড',
                keyboardType: TextInputType.text,
                prefixIcon: const Icon(Icons.qr_code_2),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _barcodeController,
                label: 'বারকোড (ঐচ্ছিক)',
                hint: 'পণ্যের বারকোড',
                keyboardType: TextInputType.text,
                prefixIcon: const Icon(Icons.qr_code),
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 16),

              // Unit dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'একক *',
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
                      color: _isSubmitting ? Colors.grey[100] : Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedUnit,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: _units.map((unit) {
                          return DropdownMenuItem<String>(
                            value: unit['value'],
                            child: Text(unit['label']!),
                          );
                        }).toList(),
                        onChanged: _isSubmitting
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _selectedUnit = value);
                                }
                              },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Prices and stock policy
              AuthTextField(
                controller: _sellingPriceController,
                label: 'বিক্রয় মূল্য *',
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: const Icon(Icons.sell),
                enabled: !_isSubmitting,
                validator: _validateNonNegativeDecimal('বিক্রয় মূল্য'),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _purchasePriceController,
                label: 'সাধারণ ক্রয় মূল্য *',
                hint: '0.00',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: const Icon(Icons.shopping_bag),
                enabled: !_isSubmitting,
                validator: _validateNonNegativeDecimal('ক্রয় মূল্য'),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _minimumStockController,
                label: 'সর্বনিম্ন স্টক',
                hint: 'স্টক কম হলে সতর্কতা',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: const Icon(Icons.notification_important),
                enabled: !_isSubmitting,
                validator: _validateNonNegativeDecimal('সর্বনিম্ন স্টক'),
              ),
              const SizedBox(height: 16),
              AuthTextField(
                controller: _targetStockDaysController,
                label: 'লক্ষ্য স্টক দিন',
                hint: '7',
                keyboardType: TextInputType.number,
                prefixIcon: const Icon(Icons.calendar_today),
                enabled: !_isSubmitting,
                validator: (value) {
                  final number = int.tryParse(value ?? '');
                  if (number == null || number < 1) return 'কমপক্ষে ১ দিন লিখুন';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Submit button
              AuthButton(
                text: isEditing ? 'সংরক্ষণ করুন' : 'তৈরি করুন',
                onPressed: _handleSubmit,
                isLoading: _isSubmitting,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? Function(String?) _validateNonNegativeDecimal(String label) => (value) {
        final number = double.tryParse(value ?? '');
        if (number == null || number < 0) return 'সঠিক $label লিখুন';
        return null;
      };
}
