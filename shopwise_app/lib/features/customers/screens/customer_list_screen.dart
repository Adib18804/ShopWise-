import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/customer_model.dart';
import '../../../models/shop_model.dart';
import '../../../providers/customer_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/shop_provider.dart';

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
    final isLibrary = ref.watch(shopTypeProvider) == ShopType.library;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isLibrary
            ? (l.isBn ? 'সদস্য' : 'Members')
            : (l.isBn ? 'বাকি খাতা' : 'Customer Credit (Baki)'),),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(customerProvider.notifier).refresh(),
          ),
        ],
      ),
      body: _body(context, l, state, isLibrary: isLibrary),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: Text(
          isLibrary
              ? (l.isBn ? 'নতুন সদস্য' : 'New Member')
              : (l.isBn ? 'নতুন গ্রাহক' : 'New Customer'),
          style: const TextStyle(color: Colors.white),
        ),
        onPressed: () => _showNewCustomerSheet(context, l, isLibrary: isLibrary),
      ),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l, CustomerState state,
      {required bool isLibrary,}) {
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
        0, (sum, c) => sum + c.totalDue,);
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
                  AppColors.riskMedium.withValues(alpha: 0.85),
                  AppColors.riskHigh.withValues(alpha: 0.85),
                ],
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    color: Colors.white,),
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
                          color: Colors.grey[400],),
                      const SizedBox(height: 16),
                      Text(
                        isLibrary
                            ? (l.isBn ? 'কোনো সদস্য নেই' : 'No members yet')
                            : (l.isBn ? 'কোনো গ্রাহক নেই' : 'No customers yet'),
                        style: const TextStyle(
                            fontSize: 18, color: AppColors.textSecondary,),
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
                      final shopName =
                          ref.read(shopProvider).shop?.shopName ?? 'ShopWise';
                      return _CustomerCard(
                        customer: customer,
                        l: l,
                        onPayment: () =>
                            _showPaymentSheet(context, customer, l),
                        onCall: () => _callCustomer(context, customer, l),
                        onMessage: () => _messageCustomer(
                            context, customer, l, shopName: shopName,),
                        onContact: () => _showContactSheet(
                            context, customer, l, shopName,),
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

  Future<void> _callCustomer(
    BuildContext context,
    CustomerModel customer,
    AppLocalizations l,
  ) async {
    if (customer.phone.trim().isEmpty) {
      _showContactError(context, l.isBn ? 'ফোন নম্বর নেই' : 'No phone number');
      return;
    }
    final launched = await launchUrl(
      Uri(scheme: 'tel', path: customer.phone.trim()),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showContactError(
          context, l.isBn ? 'কল অ্যাপ খোলা যায়নি' : 'Unable to open dialer',);
    }
  }

  Future<void> _messageCustomer(
    BuildContext context,
    CustomerModel customer,
    AppLocalizations l, {
    required String shopName,
  }) async {
    if (customer.phone.trim().isEmpty) {
      _showContactError(context, l.isBn ? 'ফোন নম্বর নেই' : 'No phone number');
      return;
    }
    final message = l.isBn
        ? 'আসসালামু আলাইকুম, আপনার $shopName-এ ${l.formatAmount(customer.totalDue)} টাকা বাকি আছে। অনুগ্রহ করে পরিশোধ করুন।'
        : 'Assalamu Alaikum, you have ${l.formatAmount(customer.totalDue)} due at $shopName. Please make the payment.';
    final launched = await launchUrl(
      Uri(
        scheme: 'sms',
        path: customer.phone.trim(),
        queryParameters: {'body': message},
      ),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      _showContactError(context,
          l.isBn ? 'মেসেজ অ্যাপ খোলা যায়নি' : 'Unable to open messaging app',);
    }
  }

  void _showContactSheet(
    BuildContext context,
    CustomerModel customer,
    AppLocalizations l,
    String shopName,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(customer.name,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,),),
            const SizedBox(height: 4),
            Text(l.formatAmount(customer.totalDue),
                style: const TextStyle(
                    color: AppColors.riskHigh, fontWeight: FontWeight.w700,),),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _callCustomer(context, customer, l);
                  },
                  icon: const Icon(Icons.call),
                  label: Text(l.isBn ? 'কল' : 'Call'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _messageCustomer(context, customer, l,
                        shopName: shopName,);
                  },
                  icon: const Icon(Icons.sms_outlined),
                  label: Text(l.isBn ? 'মেসেজ' : 'Message'),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.accent),
                ),
              ),
            ],),
          ],),
        ),
      ),
    );
  }

  void _showContactError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ───────────────────────────────────────────────────── New customer sheet ──

  void _showNewCustomerSheet(BuildContext context, AppLocalizations l,
      {required bool isLibrary,}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _NewCustomerSheet(l: l, isLibrary: isLibrary),
    );
  }

  // ─────────────────────────────────────────────────── Record payment sheet ──

  void _showPaymentSheet(
      BuildContext context, CustomerModel customer, AppLocalizations l,) {
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
      BuildContext context, CustomerModel customer, AppLocalizations l,) async {
    final isLibrary = ref.read(shopTypeProvider) == ShopType.library;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text(isLibrary
            ? (l.isBn ? 'সদস্য মুছবেন?' : 'Delete member?')
            : (l.isBn ? 'গ্রাহক মুছবেন?' : 'Delete customer?'),),
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
    if ((ok ?? false) && mounted) {
      await ref.read(customerProvider.notifier).deleteCustomer(customer.docId);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {

  const _CustomerCard({
    required this.customer,
    required this.l,
    required this.onPayment,
    required this.onCall,
    required this.onMessage,
    required this.onContact,
    required this.onDelete,
  });
  final CustomerModel customer;
  final AppLocalizations l;
  final VoidCallback onPayment;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final VoidCallback onContact;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final hasDue = customer.hasDue;
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          children: [
            Row(children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: hasDue
                    ? AppColors.riskMedium.withValues(alpha: 0.12)
                    : AppColors.primary.withValues(alpha: 0.1),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,),),
                    if (customer.phone.isNotEmpty)
                      Text(customer.phone,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary,),),
                  ],
                ),
              ),
              if (hasDue)
                InkWell(
                  onTap: onContact,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(l.formatAmount(customer.totalDue),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.riskMedium,),),
                  ),
                )
              else
                Text(l.isBn ? 'পরিষ্কার' : 'Clear',
                    style: const TextStyle(
                        color: AppColors.success, fontSize: 12,),),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
              ),
            ],),
            if (hasDue) ...[
              const Divider(height: 14),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                IconButton.outlined(
                  onPressed: onCall,
                  tooltip: l.isBn ? 'কল করুন' : 'Call customer',
                  icon: const Icon(Icons.call, size: 19),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 6),
                IconButton.outlined(
                  onPressed: onMessage,
                  tooltip: l.isBn ? 'মেসেজ পাঠান' : 'Message customer',
                  icon: const Icon(Icons.sms_outlined, size: 19),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onPayment,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: Text(l.isBn ? 'পেমেন্ট' : 'Pay'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.success),
                ),
              ],),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CustomerModel>('customer', customer));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onPayment', onPayment));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onCall', onCall));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onMessage', onMessage));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onContact', onContact));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onDelete', onDelete));
  }
}

// ─────────────────────────────────────────────────────── New Customer Sheet ──

class _NewCustomerSheet extends ConsumerStatefulWidget {

  const _NewCustomerSheet({required this.l, required this.isLibrary});
  final AppLocalizations l;
  final bool isLibrary;

  @override
  ConsumerState<_NewCustomerSheet> createState() => _NewCustomerSheetState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
    properties.add(DiagnosticsProperty<bool>('isLibrary', isLibrary));
  }
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
          bottom: MediaQuery.of(context).viewInsets.bottom,),
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
                widget.isLibrary
                    ? (l.isBn ? 'নতুন সদস্য যোগ করুন' : 'Add New Member')
                    : (l.isBn ? 'নতুন গ্রাহক যোগ করুন' : 'Add New Customer'),
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
                        borderRadius: BorderRadius.circular(14),),
                  ),
                  onPressed: state.isSubmitting ? null : _submit,
                  child: state.isSubmitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5,),)
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

  const _RecordPaymentSheet({required this.customer, required this.l});
  final CustomerModel customer;
  final AppLocalizations l;

  @override
  ConsumerState<_RecordPaymentSheet> createState() =>
      _RecordPaymentSheetState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<CustomerModel>('customer', customer));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
  }
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
          bottom: MediaQuery.of(context).viewInsets.bottom,),
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
                    fontSize: 15, color: AppColors.textSecondary,),
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
                      RegExp(r'^\d*\.?\d{0,2}'),),
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
                        borderRadius: BorderRadius.circular(14),),
                  ),
                  onPressed: state.isSubmitting ? null : _submit,
                  child: state.isSubmitting
                      ? const SizedBox.square(
                          dimension: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5,),)
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
