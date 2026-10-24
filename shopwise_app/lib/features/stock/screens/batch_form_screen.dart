import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/batch_model.dart';
import '../../../providers/batch_provider.dart';

class BatchFormScreen extends ConsumerStatefulWidget {
  final int productId;
  final String productName;
  final String unit;
  final BatchModel? batch;

  const BatchFormScreen({
    super.key,
    required this.productId,
    required this.productName,
    required this.unit,
    this.batch,
  });

  @override
  ConsumerState<BatchFormScreen> createState() => _BatchFormScreenState();
}

class _BatchFormScreenState extends ConsumerState<BatchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _number = TextEditingController();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  late DateTime _purchaseDate;
  DateTime? _expiryDate;
  bool _submitting = false;

  bool get _editing => widget.batch != null;

  @override
  void initState() {
    super.initState();
    _purchaseDate = widget.batch?.purchaseDate ?? DateTime.now();
    _expiryDate = widget.batch?.expiryDate;
    _number.text = widget.batch?.batchNumber ?? '';
    _quantity.text = widget.batch?.quantity.toString() ?? '';
    _price.text = widget.batch?.purchasePrice.toString() ?? '';
  }

  @override
  void dispose() {
    _number.dispose();
    _quantity.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _chooseDate({required bool expiry}) async {
    final today = DateTime.now();
    final earliestExpiry = DateTime(_purchaseDate.year, _purchaseDate.month, _purchaseDate.day)
        .add(const Duration(days: 1));
    final initialExpiry = _expiryDate == null || _expiryDate!.isBefore(earliestExpiry)
        ? earliestExpiry
        : _expiryDate!;
    final picked = await showDatePicker(
      context: context,
      initialDate: expiry ? initialExpiry : _purchaseDate,
      firstDate: expiry ? earliestExpiry : DateTime(2000),
      lastDate: expiry ? DateTime(2100) : today,
      helpText: expiry ? 'মেয়াদ শেষের তারিখ' : 'ক্রয়ের তারিখ',
    );
    if (picked != null && mounted) {
      setState(() {
        if (expiry) {
          _expiryDate = picked;
        } else {
          _purchaseDate = picked;
          if (_expiryDate != null && !_expiryDate!.isAfter(_purchaseDate)) _expiryDate = null;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_editing && _expiryDate != null && !_expiryDate!.isAfter(_purchaseDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('মেয়াদ শেষের তারিখ ক্রয়ের তারিখের পরে হতে হবে')),
      );
      return;
    }
    final quantity = double.tryParse(_quantity.text.trim()) ?? 0.0;
    final purchasePrice = double.tryParse(_price.text.trim()) ?? 0.0;
    if (!quantity.isFinite || (!_editing && quantity <= 0) || (_editing && quantity < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u09AA\u09B0\u09BF\u09AE\u09BE\u09A3 \u0985\u09AC\u09B6\u09CD\u09AF\u0987 \u09E6 \u098F\u09B0 \u09AC\u09C7\u09B6\u09BF \u09B9\u09AC\u09C7',
          ),
        ),
      );
      return;
    }
    if (!purchasePrice.isFinite || purchasePrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '\u0995\u09CD\u09B0\u09DF \u09AE\u09C2\u09B2\u09CD\u09AF \u09B8\u09A0\u09BF\u0995 \u09A8\u09DF',
          ),
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final notifier = ref.read(batchProvider(widget.productId).notifier);
    final success = _editing
        ? await notifier.updateBatch(widget.batch!.id, {
            'quantity': quantity,
            'purchase_price': purchasePrice,
            'expiry_date': _expiryDate == null ? null : _dateOnly(_expiryDate!),
          })
        : await notifier.addBatch(
            batchNumber: _number.text.trim().isEmpty ? null : _number.text.trim(),
            purchaseDate: _purchaseDate,
            expiryDate: _expiryDate,
            quantity: quantity,
            purchasePrice: purchasePrice,
          );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (success) {
      Navigator.of(context).pop(true);
    } else {
      final message = ref.read(batchProvider(widget.productId)).error ?? 'সংরক্ষণ করা যায়নি';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'ব্যাচ সম্পাদনা' : 'স্টক যোগ করুন'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(widget.productName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              if (!_editing) ...[
                TextFormField(
                  controller: _number,
                  decoration: const InputDecoration(labelText: 'ব্যাচ নম্বর (ঐচ্ছিক)', border: OutlineInputBorder()),
                  enabled: !_submitting,
                  maxLength: 100,
                ),
                const SizedBox(height: 10),
                _dateTile('ক্রয়ের তারিখ', _purchaseDate, () => _chooseDate(expiry: false)),
              ],
              const SizedBox(height: 10),
              _dateTile(
                'মেয়াদ শেষের তারিখ',
                _expiryDate,
                () => _chooseDate(expiry: true),
                clearable: true,
                onClear: () => setState(() => _expiryDate = null),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _quantity,
                decoration: InputDecoration(
                  labelText: 'পরিমাণ *', border: const OutlineInputBorder(), suffixText: widget.unit,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                enabled: !_submitting,
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  if (amount == null || amount < (_editing ? 0 : 0.01)) {
                    return _editing ? 'শূন্য বা তার বেশি পরিমাণ দিন' : 'শূন্যের বেশি পরিমাণ দিন';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _price,
                decoration: const InputDecoration(labelText: 'প্রতি এককের ক্রয় মূল্য *', border: OutlineInputBorder(), prefixText: '৳ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                enabled: !_submitting,
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  if (amount == null || amount < 0) return 'শূন্য বা তার বেশি মূল্য দিন';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _submitting ? null : _save,
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(_editing ? 'পরিবর্তন সংরক্ষণ করুন' : 'স্টক সংরক্ষণ করুন'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap, {bool clearable = false, VoidCallback? onClear}) {
    return Card(
      child: ListTile(
        onTap: _submitting ? null : onTap,
        leading: const Icon(Icons.calendar_month),
        title: Text(label),
        subtitle: Text(value == null ? 'তারিখ নির্বাচন করুন' : _dateOnly(value)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (clearable && value != null)
            IconButton(onPressed: _submitting ? null : onClear, icon: const Icon(Icons.close), tooltip: 'তারিখ মুছুন'),
          const Icon(Icons.chevron_right),
        ]),
      ),
    );
  }

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
