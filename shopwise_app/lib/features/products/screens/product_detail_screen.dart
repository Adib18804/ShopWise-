import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/product_provider.dart';
import '../../../models/product_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../stock/screens/batch_list_screen.dart';
import 'product_form_screen.dart';

/// Product detail screen
class ProductDetailScreen extends ConsumerWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  String _getUnitLabel(String unit) {
    const unitMap = {
      'piece': 'টি',
      'kg': 'কেজি',
      'liter': 'লিটার',
      'packet': 'প্যাকেট',
      'box': 'বক্স',
      'dozen': 'ডজন',
    };
    return unitMap[unit] ?? unit;
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('পণ্য ডিলিট করুন'),
        content: Text('আপনি কি "${product.name}" পণ্য ডিলিট করতে চান?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('না'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('হ্যাঁ'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final success =
          await ref.read(productProvider.notifier).deleteProduct(product.id);

      if (!context.mounted) return;

      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('পণ্য ডিলিট হয়েছে'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final error = ref.read(productProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error ?? 'পণ্য ডিলিট করতে ব্যর্থ'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayedProduct = ref.watch(productProvider.select((state) {
      for (final item in state.products) {
        if (item.id == product.id) return item;
      }
      return product;
    }));
    return Scaffold(
      appBar: AppBar(
        title: const Text('পণ্যের বিবরণ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final result = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (_) => ProductFormScreen(product: displayedProduct),
                ),
              );

              if (result == true && context.mounted) {
                Navigator.of(context).pop(true);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _handleDelete(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name
            Text(
              displayedProduct.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Category
            Row(
              children: [
                Icon(
                  Icons.category,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  displayedProduct.category?.name ?? 'অজানা',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Stock status card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: displayedProduct.isOutOfStock
                    ? AppColors.error.withOpacity(0.1)
                    : displayedProduct.isLowStock
                        ? Colors.orange.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: displayedProduct.isOutOfStock
                      ? AppColors.error
                      : displayedProduct.isLowStock
                          ? Colors.orange
                          : Colors.green,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    displayedProduct.isOutOfStock
                        ? Icons.cancel
                        : displayedProduct.isLowStock
                            ? Icons.warning
                            : Icons.check_circle,
                    color: displayedProduct.isOutOfStock
                        ? AppColors.error
                        : displayedProduct.isLowStock
                            ? Colors.orange
                            : Colors.green,
                    size: 40,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayedProduct.isOutOfStock
                              ? 'স্টক শেষ'
                              : displayedProduct.isLowStock
                                  ? 'কম স্টক'
                                  : 'স্টক আছে',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: displayedProduct.isOutOfStock
                                ? AppColors.error
                                : displayedProduct.isLowStock
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                        ),
                        Text(
                          '${displayedProduct.formattedTotalStock} ${_getUnitLabel(displayedProduct.unit)}',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stock and batch management
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.inventory),
                label: const Text('স্টক ও ব্যাচ দেখুন'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BatchListScreen(product: displayedProduct),
                    ),
                  );
                  if (context.mounted) {
                    await ref.read(productProvider.notifier).refreshProducts();
                  }
                },
              ),
            ),
            const SizedBox(height: 24),

            // Details
            _buildDetailRow('বারকোড', displayedProduct.barcode ?? 'নেই'),
            _buildDetailRow('একক', _getUnitLabel(displayedProduct.unit)),
            _buildDetailRow(
                'সর্বনিম্ন স্টক', '${displayedProduct.formattedMinimumStock} ${_getUnitLabel(displayedProduct.unit)}'),
            _buildDetailRow('বিক্রয় মূল্য', '৳${displayedProduct.sellingPrice.toStringAsFixed(2)}'),
            _buildDetailRow('ক্রয় মূল্য', '৳${displayedProduct.defaultPurchasePrice.toStringAsFixed(2)}'),
            _buildDetailRow('লক্ষ্য স্টক দিন', '${displayedProduct.targetStockDays}'),
            if (displayedProduct.batchCount != null)
              _buildDetailRow('মোট ব্যাচ', '${displayedProduct.batchCount}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
