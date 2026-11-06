import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/customer_model.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/language_provider.dart';

/// Baki Khata — shows every customer with their outstanding balance.
/// FAB opens the "New Customer" form; tapping a card opens "Record Payment".
class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(customerProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(appLocalizationsProvider);
    final state = ref.watch(customerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(l.isBn ? 'বাকি খাতা' : 'Customer Credit (Baki)'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(customerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: _body(context, l, state),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text(
          l.isBn ? 'নতুন গ্রাহক' : 'New Customer',
          style: const TextStyle(color: Colors.white),
        ),
        onPressed: () => _showNewCustomerSheet(context, l),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l, CustomerState state) {
    if (state.isLoading && state.customers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Show error snackbar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (state.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.error!),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(customerProvider.notifier).clearMessages();
      }
      if (state.successMessage != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.successMessage!),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(customerProvider.notifier).clearMessages();
      }
    });

    // Summary banner — total outstanding across all customers
    final totalDue = state.customers.fold<double>(
        0, (sum, c) => sum + c.totalDue);
    final hasDue = totalDue > 0.005;

    return Column(
      children: [
        if (hasDue)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.riskMedium.withOpacity(0.85),
                  AppColors.riskHigh.withOpacity(0.85),
                ],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.isBn
                        ? 'মোট বাকি: ${l.formatAmount(totalDue)}'
                        : 'Total outstanding: ${l.formatAmount(totalDue)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: state.customers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 72,
                          color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        l.isBn ? 'কোনো গ্রাহক নেই' : 'No customers yet',
                        style: const TextStyle(
                            fontSize: 18, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(customerProvider.notifier).refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                    itemCount: state.customers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final customer = state.customers[index];
                      return _CustomerCard(
                        customer: customer,
                        l: l,
                        onPayment: () =>
                            _showPaymentSheet(context, customer, l),
                        onDelete: () =>
                            _confirmDelete(context, customer, l),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────── New customer sheet ──

  void _showNewCustomerSheet(BuildContext context, AppLocalizations l) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _NewCustomerSheet(l: l),
    );
  }

  // ─────────────────────────────────────────────────── Record payment sheet ──

  void _showPaymentSheet(
      BuildContext context, CustomerModel customer, AppLocalizations l) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) =>
          _RecordPaymentSheet(customer: customer, l: l),
    );
  }

  // ──────────────────────────────────────────────────────── Delete confirm ──

  Future<void> _confirmDelete(
      BuildContext context, CustomerModel customer, AppLocalizations l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(l.isBn ? 'গ্রাহক মুছবেন?' : 'Delete customer?'),
        content: Text(
          l.isBn
              ? '"${customer.name}" কে মুছে ফেলা হবে।'
              : 'Delete "${customer.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(l.no),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(l.yes),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(customerProvider.notifier).deleteCustomer(customer.docId);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final CustomerModel customer;
  final AppLocalizations l;
  final VoidCallback onPayment;
  final VoidCallback onDelete;

  const _CustomerCard({
    required this.customer,
    required this.l,
    required this.onPayment,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasDue = customer.hasDue;
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: hasDue
                  ? AppColors.riskMedium.withOpacity(0.12)
                  : AppColors.primary.withOpacity(0.1),
              child: Text(
                customer.name.isNotEmpty
                    ? customer.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: hasDue ? AppColors.riskMedium : AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (customer.phone.isNotEmpty)
                    Text(
                      customer.phone,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasDue) ...[
                  Text(
                    l.formatAmount(customer.totalDue),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.riskMedium,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onPayment,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        l.isBn ? 'পেমেন্ট' : 'Pay',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      l.isBn ? 'পরিষ্কার' : 'Clear',
                      style: const TextStyle(
                          color: AppColors.success, fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────── New Customer Sheet ──

class _NewCustomerSheet extends ConsumerStatefulWidget {
  final AppLocalizations l;

  const _NewCustomerSheet({required this.l});

  @override
  ConsumerState<_NewCustomerSheet> createState() => _NewCustomerSheetState();
}

class _NewCustomerSheetState extends ConsumerState<_NewCustomerSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final customer = await ref.read(customerProvider.notifier).createCustomer(
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
        );
    if (!mounted) return;
    if (customer != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final state = ref.watch(customerProvider);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l.isBn ? 'নতুন গ্রাহক যোগ করুন' : 'Add New Customer',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                enabled: !state.isSubmitting,
                decoration: InputDecoration(
                  labelText: l.isBn ? 'নাম *' : 'Name *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? (l.isBn ? 'নাম প্রয়োজন' : 'Name required')
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneCtrl,
                enabled: !state.isSubmitting,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l.isBn ? 'ফোন নম্বর *' : 'Phone *',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return l.isBn
                        ? 'ফোন নম্বর প্রয়োজন'
                        : 'Phone required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: state.isSubmitting ? null : _submit,
                  child: state.isSubmitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          l.isBn ? 'সংরক্ষণ করুন' : 'Save',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────── Record Payment Sheet ──

class _RecordPaymentSheet extends ConsumerStatefulWidget {
  final CustomerModel customer;
  final AppLocalizations l;

  const _RecordPaymentSheet({required this.customer, required this.l});

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends ConsumerState<_RecordPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    // Pre-fill with full due amount.
    _amountCtrl.text = widget.customer.totalDue.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final updated = await ref
        .read(customerProvider.notifier)
        .recordPayment(widget.customer.docId, amount);
    if (!mounted) return;
    if (updated != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final state = ref.watch(customerProvider);

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 18),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                l.isBn ? 'পেমেন্ট রেকর্ড করুন' : 'Record Payment',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.customer.name,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '${l.isBn ? 'বর্তমান বাকি' : 'Current balance'}: '
                '${l.formatAmount(widget.customer.totalDue)}',
                style: const TextStyle(
                  color: AppColors.riskMedium,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountCtrl,
                enabled: !state.isSubmitting,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'))
                ],
                decoration: InputDecoration(
                  labelText:
                      l.isBn ? 'পেমেন্টের পরিমাণ *' : 'Payment Amount *',
                  prefixText: '৳ ',
                  border: const OutlineInputBorder(),
                  prefixIcon:
                      const Icon(Icons.payments_outlined),
                ),
                validator: (v) {
                  final n = double.tryParse(v ?? '');
                  if (n == null || n <= 0) {
                    return l.isBn
                        ? 'সঠিক পরিমাণ লিখুন'
                        : 'Enter a valid amount';
                  }
                  if (n > widget.customer.totalDue + 0.01) {
                    return l.isBn
                        ? 'পেমেন্ট বাকির বেশি হতে পারে না'
                        : 'Cannot exceed balance';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: state.isSubmitting ? null : _submit,
                  child: state.isSubmitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text(
                          l.isBn ? 'পেমেন্ট সংরক্ষণ করুন' : 'Save Payment',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
