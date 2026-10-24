import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/batch_model.dart';
import '../../../models/product_model.dart';
import '../../../providers/batch_provider.dart';
import 'batch_detail_screen.dart';
import 'batch_form_screen.dart';
import 'fefo_screen.dart';
import 'stock_history_screen.dart';

class BatchListScreen extends ConsumerStatefulWidget {
  final ProductModel product;
  const BatchListScreen({super.key, required this.product});

  @override
  ConsumerState<BatchListScreen> createState() => _BatchListScreenState();
}

class _BatchListScreenState extends ConsumerState<BatchListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(batchProvider(widget.product.id).notifier).load());
  }

  Future<void> _openAddBatch() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
      builder: (_) => BatchFormScreen(
        productId: widget.product.id,
        productName: widget.product.name,
        unit: widget.product.unit,
      ),
    ));
    if (saved == true && mounted) {
      await ref.read(batchProvider(widget.product.id).notifier).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(batchProvider(widget.product.id));
    final notifier = ref.read(batchProvider(widget.product.id).notifier);
    return Scaffold(
      appBar: AppBar(
        title: const Text('স্টক ও ব্যাচ'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'স্টক ইতিহাস',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => StockHistoryScreen(productId: widget.product.id, productName: widget.product.name),
            )),
          ),
          IconButton(
            tooltip: 'FEFO পরামর্শ',
            icon: const Icon(Icons.sort),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => FefoScreen(productId: widget.product.id, productName: widget.product.name),
            )),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddBatch,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('স্টক যোগ করুন'),
      ),
      body: RefreshIndicator(
        onRefresh: notifier.load,
        child: state.isLoading && state.batches.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Card(
                    child: ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.inventory_2)),
                      title: Text(widget.product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('মোট স্টক: ${_quantity(state.currentStock)} ${widget.product.unit}'),
                    ),
                  ),
                  if (state.error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: ListTile(
                        leading: const Icon(Icons.error_outline, color: Colors.red),
                        title: Text(state.error!),
                        trailing: IconButton(icon: const Icon(Icons.refresh), onPressed: notifier.load),
                      ),
                    ),
                  if (!state.isLoading && state.batches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 48),
                      child: Center(child: Text('কোনো ব্যাচ নেই। স্টক যোগ করুন।')),
                    ),
                  ...state.batches.map((batch) => _BatchCard(
                        batch: batch,
                        unit: widget.product.unit,
                        onTap: () async {
                          final changed = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
                            builder: (_) => BatchDetailScreen(product: widget.product, batch: batch),
                          ));
                          if (changed == true && mounted) await notifier.load();
                        },
                      )),
                ],
              ),
      ),
    );
  }

  static String _quantity(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
}

class _BatchCard extends StatelessWidget {
  final BatchModel batch;
  final String unit;
  final VoidCallback onTap;
  const _BatchCard({required this.batch, required this.unit, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = batch.status ?? 'ACTIVE';
    final color = switch (status) {
      'EXPIRED' => Colors.red,
      'NEAR_EXPIRY' => Colors.deepOrange,
      'LOW_STOCK' => Colors.orange,
      'DEPLETED' => Colors.grey,
      _ => Colors.green,
    };
    return Card(
      margin: const EdgeInsets.only(top: 10),
      child: ListTile(
        onTap: onTap,
        title: Text(batch.batchNumber?.isNotEmpty == true ? batch.batchNumber! : 'ব্যাচ #${batch.id}'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('পরিমাণ: ${batch.quantity} $unit  •  ক্রয়: ৳${batch.purchasePrice.toStringAsFixed(2)}'),
            const SizedBox(height: 5),
            Text(batch.expiryStatusText),
          ]),
        ),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.circle, color: color, size: 13),
          const SizedBox(height: 4),
          Text(_statusLabel(status), style: TextStyle(color: color, fontSize: 11)),
        ]),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
        'EXPIRED' => 'মেয়াদ শেষ',
        'NEAR_EXPIRY' => 'মেয়াদ আসন্ন',
        'LOW_STOCK' => 'কম স্টক',
        'DEPLETED' => 'শেষ',
        _ => 'সক্রিয়',
      };
}
