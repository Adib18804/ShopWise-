import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/batch_provider.dart';

class FefoScreen extends ConsumerStatefulWidget {
  final int productId;
  final String productName;
  const FefoScreen({super.key, required this.productId, required this.productName});

  @override
  ConsumerState<FefoScreen> createState() => _FefoScreenState();
}

class _FefoScreenState extends ConsumerState<FefoScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(batchProvider(widget.productId).notifier).loadFefo());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchProvider(widget.productId));
    final result = state.fefo;
    final batches = (result?['batches'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('কোন ব্যাচ আগে বিক্রি করবেন'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: result == null && state.error == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(widget.productName, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('আগে মেয়াদ শেষ হবে এমন স্টক আগে বিক্রির পরামর্শ। সিদ্ধান্ত আপনার।'),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(state.error!, style: const TextStyle(color: Colors.red)),
                ],
                if (batches.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 42),
                    child: Center(child: Text('মেয়াদযুক্ত সক্রিয় ব্যাচ পাওয়া যায়নি')),
                  ),
                ...batches.map((raw) {
                  final batch = raw as Map<String, dynamic>;
                  final priority = (batch['priority'] as num?)?.toInt() ?? 0;
                  final expiry = batch['expiry_date']?.toString() ?? '';
                  final quantity = (batch['quantity'] as num?)?.toDouble() ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(top: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: priority == 1 ? Colors.deepOrange.withOpacity(0.12) : AppColors.primary.withOpacity(0.1),
                        child: Text('$priority', style: TextStyle(color: priority == 1 ? Colors.deepOrange : AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(batch['batch_number'] as String? ?? 'ব্যাচ #${batch['batch_id']}'),
                      subtitle: Text('মেয়াদ: $expiry • ${batch['days_until_expiry']} দিন বাকি'),
                      trailing: Text(_quantity(quantity)),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  String _quantity(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
}
