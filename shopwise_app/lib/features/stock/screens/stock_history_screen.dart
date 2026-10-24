import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/batch_provider.dart';

class StockHistoryScreen extends ConsumerStatefulWidget {
  final int productId;
  final String productName;
  const StockHistoryScreen({super.key, required this.productId, required this.productName});

  @override
  ConsumerState<StockHistoryScreen> createState() => _StockHistoryScreenState();
}

class _StockHistoryScreenState extends ConsumerState<StockHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(batchProvider(widget.productId).notifier).loadStockHistory());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchProvider(widget.productId));
    final notifier = ref.read(batchProvider(widget.productId).notifier);
    final history = state.stockHistory;
    final transactions = (history?['transactions'] as List?) ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('স্টক ইতিহাস'), backgroundColor: AppColors.primary, foregroundColor: Colors.white),
      body: state.isLoading && history == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: notifier.loadStockHistory,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(widget.productName, style: Theme.of(context).textTheme.titleLarge),
                  if (state.error != null) ...[
                    const SizedBox(height: 12),
                    Text(state.error!, style: const TextStyle(color: Colors.red)),
                  ],
                  if (transactions.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: Text('এখনও কোনো স্টক ইতিহাস নেই')),
                    ),
                  ...transactions.map((raw) {
                    final transaction = raw as Map<String, dynamic>;
                    final type = transaction['transaction_type'] as String? ?? '';
                    final amount = (transaction['quantity'] as num?)?.toDouble() ?? 0;
                    final added = const {'PURCHASE', 'ADJUSTMENT_IN', 'RETURN'}.contains(type);
                    return Card(
                      margin: const EdgeInsets.only(top: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (added ? Colors.green : Colors.orange).withOpacity(0.12),
                          child: Icon(added ? Icons.add : Icons.remove, color: added ? Colors.green : Colors.orange),
                        ),
                        title: Text(_typeLabel(type)),
                        subtitle: Text([
                          if (transaction['batch_number'] != null) 'ব্যাচ: ${transaction['batch_number']}',
                          if (transaction['notes'] != null) transaction['notes'].toString(),
                          _dateLabel(transaction['created_at']?.toString()),
                        ].join(' • ')),
                        trailing: Text('${added ? '+' : '-'}${_quantity(amount)}', style: TextStyle(fontWeight: FontWeight.bold, color: added ? Colors.green : Colors.orange)),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'PURCHASE' => 'নতুন স্টক',
        'ADJUSTMENT_IN' => 'স্টক সমন্বয় (যোগ)',
        'ADJUSTMENT_OUT' => 'স্টক সমন্বয় (কম)',
        'SALE' => 'বিক্রয়',
        'RETURN' => 'ফেরত',
        'EXPIRED' => 'মেয়াদ শেষ',
        'DAMAGED' => 'নষ্ট পণ্য',
        _ => type,
      };

  String _dateLabel(String? value) {
    if (value == null) return '';
    return value.replaceFirst('T', ' ').split('.').first;
  }

  String _quantity(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
}
