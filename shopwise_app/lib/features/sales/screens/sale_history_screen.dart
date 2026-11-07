import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/sale_model.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/sale_history_provider.dart';

/// Displays a real-time list of all invoices for the shop.
/// Tapping any row opens [_InvoiceDetailSheet].
class SaleHistoryScreen extends ConsumerStatefulWidget {
  const SaleHistoryScreen({super.key});

  @override
  ConsumerState<SaleHistoryScreen> createState() => _SaleHistoryScreenState();
}

class _SaleHistoryScreenState extends ConsumerState<SaleHistoryScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(saleHistoryProvider.notifier).init());
  }

  @override
  Widget build(BuildContext context) {
    final l = ref.watch(appLocalizationsProvider);
    final state = ref.watch(saleHistoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isBn(l) ? 'বিক্রয় ইতিহাস' : 'Sale History'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l.retry,
            onPressed: () => ref.read(saleHistoryProvider.notifier).refresh(),
          ),
        ],
      ),
      body: _body(context, l, state),
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l,
    SaleHistoryState state,
  ) {
    if (state.isLoading && state.invoices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null && state.invoices.isEmpty) {
      return _ErrorView(
        message: state.error!,
        onRetry: () => ref.read(saleHistoryProvider.notifier).refresh(),
      );
    }
    if (state.invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              isBn(l) ? 'কোনো বিক্রয় নেই' : 'No sales yet',
              style: const TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(saleHistoryProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: state.invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final invoice = state.invoices[index];
          return _InvoiceCard(
            invoice: invoice,
            l: l,
            onTap: () => _showDetail(context, invoice, l),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, SaleModel invoice, AppLocalizations l) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (_) => _InvoiceDetailSheet(invoice: invoice, l: l),
    );
  }

  static bool isBn(AppLocalizations l) => l.isBn;
}

// ─────────────────────────────────────────────────────────────────────────────

class _InvoiceCard extends StatelessWidget {

  const _InvoiceCard({
    required this.invoice,
    required this.l,
    required this.onTap,
  });
  final SaleModel invoice;
  final AppLocalizations l;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasDue = invoice.dueAmount > 0.005;
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Invoice icon badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: hasDue
                      ? AppColors.riskMedium.withValues(alpha: 0.12)
                      : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.receipt_long_rounded,
                  color: hasDue ? AppColors.riskMedium : AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invoice.invoiceNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (invoice.createdAt != null)
                      Text(
                        l.formatDateTime(invoice.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    if (invoice.customerName != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 13, color: AppColors.textSecondary,),
                          const SizedBox(width: 4),
                          Text(
                            invoice.customerName!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textSecondary,),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    l.formatAmount(invoice.totalAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  if (hasDue) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2,),
                      decoration: BoxDecoration(
                        color: AppColors.riskMedium.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${l.isBn ? 'বাকি' : 'Due'}: ${l.formatAmount(invoice.dueAmount)}',
                        style: const TextStyle(
                          color: AppColors.riskMedium,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SaleModel>('invoice', invoice));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Modal bottom-sheet showing the full detail of a single invoice.
class _InvoiceDetailSheet extends StatelessWidget {

  const _InvoiceDetailSheet({required this.invoice, required this.l});
  final SaleModel invoice;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final hasDue = invoice.dueAmount > 0.005;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          // Drag handle
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invoice.invoiceNumber,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (invoice.createdAt != null)
                        Text(
                          l.formatDateTime(invoice.createdAt),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary,),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Customer row (if any)
                  if (invoice.customerName != null) ...[
                    _Row(
                      icon: Icons.person_outline,
                      label: l.isBn ? 'গ্রাহক' : 'Customer',
                      value: invoice.customerName!,
                    ),
                    const SizedBox(height: 8),
                  ],
                  // Payment method
                  _Row(
                    icon: Icons.payments_outlined,
                    label: l.isBn ? 'পেমেন্ট' : 'Payment',
                    value: _paymentLabel(invoice.paymentMethod, l),
                  ),
                  const SizedBox(height: 18),
                  // Items
                  Text(
                    l.isBn ? 'পণ্যসমূহ' : 'Items',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...invoice.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.productName ??
                                  (l.isBn ? 'পণ্য' : 'Product'),
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          Text(
                            '${l.formatQty(item.quantity)} × ${l.formatAmount(item.unitPrice)}',
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l.formatAmount(item.totalPrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 24),
                  // Totals
                  _TotalRow(
                    label: l.isBn ? 'সাবটোটাল' : 'Subtotal',
                    value: l.formatAmount(
                        invoice.totalAmount + invoice.discount,),
                  ),
                  if (invoice.discount > 0)
                    _TotalRow(
                      label: l.isBn ? 'ছাড়' : 'Discount',
                      value: '- ${l.formatAmount(invoice.discount)}',
                      valueColor: AppColors.success,
                    ),
                  _TotalRow(
                    label: l.isBn ? 'মোট' : 'Total',
                    value: l.formatAmount(invoice.totalAmount),
                    bold: true,
                  ),
                  _TotalRow(
                    label: l.isBn ? 'জমা' : 'Paid',
                    value: l.formatAmount(invoice.paidAmount),
                    valueColor: AppColors.success,
                  ),
                  if (hasDue)
                    _TotalRow(
                      label: l.isBn ? 'বাকি' : 'Due',
                      value: l.formatAmount(invoice.dueAmount),
                      bold: true,
                      valueColor: AppColors.riskMedium,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _paymentLabel(String method, AppLocalizations l) {
    if (!l.isBn) return method;
    switch (method.toLowerCase()) {
      case 'cash':
        return 'নগদ';
      case 'bkash':
        return 'বিকাশ';
      case 'nagad':
        return 'নগদ (নগদ)';
      default:
        return method;
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<SaleModel>('invoice', invoice));
    properties.add(DiagnosticsProperty<AppLocalizations>('l', l));
  }
}

class _Row extends StatelessWidget {

  const _Row({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13,),),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13,),),
        ],
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(StringProperty('label', label));
    properties.add(StringProperty('value', value));
  }
}

class _TotalRow extends StatelessWidget {

  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                fontSize: bold ? 15 : 14,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                fontSize: bold ? 16 : 14,
                color: valueColor ?? AppColors.textPrimary,
              ),
            ),
          ],
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('label', label));
    properties.add(StringProperty('value', value));
    properties.add(DiagnosticsProperty<bool>('bold', bold));
    properties.add(ColorProperty('valueColor', valueColor));
  }
}

class _ErrorView extends StatelessWidget {

  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 56, color: AppColors.error),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('আবার চেষ্টা'),
              ),
            ],
          ),
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('message', message));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onRetry', onRetry));
  }
}
