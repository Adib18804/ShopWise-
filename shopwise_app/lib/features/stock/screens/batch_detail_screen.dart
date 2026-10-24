import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/batch_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/batch_provider.dart';
import 'batch_form_screen.dart';

class BatchDetailScreen extends ConsumerWidget {
  final ProductModel product;
  final BatchModel batch;
  const BatchDetailScreen({super.key, required this.product, required this.batch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = batch.status ?? 'ACTIVE';
    final color = switch (status) {
      'EXPIRED' => Colors.red,
      'NEAR_EXPIRY' => Colors.deepOrange,
      'LOW_STOCK' => Colors.orange,
      'DEPLETED' => Colors.grey,
      _ => Colors.green,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('ব্যাচের বিবরণ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'সম্পাদনা',
            icon: const Icon(Icons.edit),
            onPressed: batch.isActive
                ? () async {
                    final updated = await Navigator.of(context).push<bool>(MaterialPageRoute(
                      builder: (_) => BatchFormScreen(
                        productId: product.id,
                        productName: product.name,
                        unit: product.unit,
                        batch: batch,
                      ),
                    ));
                    if (updated == true && context.mounted) Navigator.of(context).pop(true);
                  }
                : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.name, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(batch.batchNumber?.isNotEmpty == true ? batch.batchNumber! : 'ব্যাচ #${batch.id}'),
                const SizedBox(height: 16),
                Chip(label: Text(_statusLabel(status)), backgroundColor: color.withOpacity(0.12), labelStyle: TextStyle(color: color)),
                const Divider(height: 24),
                _detail('পরিমাণ', '${batch.quantity} ${product.unit}'),
                _detail('ক্রয় মূল্য', '৳${batch.purchasePrice.toStringAsFixed(2)}'),
                _detail('ক্রয়ের তারিখ', _date(batch.purchaseDate)),
                _detail('মেয়াদ শেষ', batch.expiryDate == null ? 'মেয়াদ নেই' : _date(batch.expiryDate!)),
                _detail('মেয়াদের অবস্থা', batch.expiryStatusText),
                _detail('মোট মূল্য', '৳${batch.totalValue.toStringAsFixed(2)}'),
              ]),
            ),
          ),
          if (batch.quantity <= 0 && batch.isActive) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _deactivate(context, ref),
              icon: const Icon(Icons.archive_outlined),
              label: const Text('ব্যাচ বন্ধ করুন'),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('বন্ধ করলে ইতিহাস সংরক্ষিত থাকবে।', textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ব্যাচ বন্ধ করবেন?'),
        content: const Text('ব্যাচের ইতিহাস থাকবে, তবে এটি বর্তমান স্টক তালিকা থেকে সরবে।'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ফিরে যান')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('বন্ধ করুন')),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    final success = await ref.read(batchProvider(product.id).notifier).deactivateBatch(batch.id);
    if (!context.mounted) return;
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final message = ref.read(batchProvider(product.id)).error ?? 'ব্যাচ বন্ধ করা যায়নি';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  static Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          SizedBox(width: 130, child: Text(label, style: const TextStyle(color: Colors.black54))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ]),
      );

  static String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  static String _statusLabel(String status) => switch (status) {
        'EXPIRED' => 'মেয়াদ শেষ',
        'NEAR_EXPIRY' => 'মেয়াদ আসন্ন',
        'LOW_STOCK' => 'কম স্টক',
        'DEPLETED' => 'স্টক শেষ',
        _ => 'সক্রিয়',
      };
}
