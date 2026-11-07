import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/product_model.dart';
import '../../../models/sale_request.dart';
import '../../../models/shop_model.dart';
import '../../../providers/language_provider.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/sales_provider.dart';
import '../../../providers/shop_provider.dart';

class CreateSaleScreen extends ConsumerStatefulWidget {
  const CreateSaleScreen({super.key});

  @override
  ConsumerState<CreateSaleScreen> createState() => _CreateSaleScreenState();
}

class _CreateSaleScreenState extends ConsumerState<CreateSaleScreen> {
  final _searchController = TextEditingController();
  final _discountController = TextEditingController(text: '0.00');
  final _paidController = TextEditingController(text: '0.00');
  final Map<int, _SaleCartLine> _cart = {};
  Timer? _searchDebounce;
  String _searchQuery = '';
  String _paymentMethod = 'cash';
  bool _paidAmountEdited = false;
  DateTime? _returnDate;

  int get _subtotalCents => _cart.values.fold<int>(
        0,
        (sum, line) =>
            sum +
            _lineTotalCents(
                line.quantityCents, _toCents(line.product.sellingPrice),),
      );

  int get _discountCents => _parseCents(_discountController.text) ?? 0;

  int get _payableCents =>
      (_subtotalCents - _discountCents).clamp(0, 999999999999);

  @override
  void initState() {
    super.initState();
    _discountController.addListener(_onTotalsChanged);
    _paidController.addListener(_onTotalsChanged);
    Future.microtask(() {
      if (mounted && ref.read(productProvider).products.isEmpty) {
        ref.read(productProvider.notifier).loadProducts();
      }
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    super.dispose();
  }

  void _onTotalsChanged() {
    if (!_paidAmountEdited) _setPaidAmount(_payableCents);
    if (mounted) setState(() {});
  }

  void _setPaidAmount(int cents) {
    final value = _formatMoney(cents);
    if (_paidController.text == value) return;
    _paidController.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _searchQuery = value.trim().toLowerCase());
    });
  }

  List<ProductModel> _visibleProducts(List<ProductModel> products) {
    if (_searchQuery.isEmpty) return products;
    return products.where((product) => product.name.toLowerCase().contains(_searchQuery) ||
          (product.sku?.toLowerCase().contains(_searchQuery) ?? false) ||
          (product.barcode?.toLowerCase().contains(_searchQuery) ?? false),).toList(growable: false);
  }

  void _addProduct(ProductModel product) {
    final current = _cart[product.id]?.quantityCents ?? 0;
    final available = _toQuantityCents(product.totalStock);
    if (current + 100 > available) {
      _showMessage(
          '\u098f\u0987 \u09aa\u09a3\u09cd\u09af\u09c7\u09b0 \u09aa\u09b0\u09cd\u09af\u09be\u09aa\u09cd\u09a4 \u09b8\u09cd\u099f\u0995 \u09a8\u09c7\u0987',);
      return;
    }
    setState(() => _cart[product.id] = _SaleCartLine(
          product: product,
          quantityCents: current + 100,
        ),);
    _syncDefaultPaidAmount();
  }

  void _changeQuantity(_SaleCartLine line, int deltaCents) {
    final next = line.quantityCents + deltaCents;
    if (next <= 0) {
      setState(() => _cart.remove(line.product.id));
    } else if (next > _toQuantityCents(line.product.totalStock)) {
      _showMessage(
          '\u09b8\u09cd\u099f\u0995\u09c7\u09b0 \u099a\u09c7\u09df\u09c7 \u09ac\u09c7\u09b6\u09bf \u09aa\u09b0\u09bf\u09ae\u09be\u09a3 \u09ac\u09bf\u0995\u09cd\u09b0\u09bf \u0995\u09b0\u09be \u09af\u09be\u09ac\u09c7 \u09a8\u09be',);
      return;
    } else {
      setState(
          () => _cart[line.product.id] = line.copyWith(quantityCents: next),);
    }
    _syncDefaultPaidAmount();
  }

  Future<void> _editQuantity(_SaleCartLine line) async {
    final controller =
        TextEditingController(text: _formatQuantity(line.quantityCents));
    final quantity = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
            '\u09aa\u09b0\u09bf\u09ae\u09be\u09a3 \u09aa\u09b0\u09bf\u09ac\u09b0\u09cd\u09a4\u09a8 \u0995\u09b0\u09c1\u09a8',),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          decoration: InputDecoration(
              labelText:
                  '\u09aa\u09b0\u09bf\u09ae\u09be\u09a3 (${line.product.unit})',),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('\u09ac\u09be\u09a4\u09bf\u09b2'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, double.tryParse(controller.text)),
            child: const Text('\u09a0\u09bf\u0995 \u0986\u099b\u09c7'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || quantity == null) return;
    final quantityCents = _toQuantityCents(quantity);
    if (quantityCents <= 0) {
      _showMessage(
          '\u09aa\u09b0\u09bf\u09ae\u09be\u09a3 \u09b6\u09c2\u09a8\u09cd\u09af\u09c7\u09b0 \u09ac\u09c7\u09b6\u09bf \u09b9\u09a4\u09c7 \u09b9\u09ac\u09c7',);
      return;
    }
    if (quantityCents > _toQuantityCents(line.product.totalStock)) {
      _showMessage(
          '\u09b8\u09cd\u099f\u0995\u09c7\u09b0 \u099a\u09c7\u09df\u09c7 \u09ac\u09c7\u09b6\u09bf \u09aa\u09b0\u09bf\u09ae\u09be\u09a3 \u09ac\u09bf\u0995\u09cd\u09b0\u09bf \u0995\u09b0\u09be \u09af\u09be\u09ac\u09c7 \u09a8\u09be',);
      return;
    }
    setState(() =>
        _cart[line.product.id] = line.copyWith(quantityCents: quantityCents),);
    _syncDefaultPaidAmount();
  }

  void _syncDefaultPaidAmount() {
    if (!_paidAmountEdited) _setPaidAmount(_payableCents);
  }

  Future<void> _confirmSale() async {
    final isLibrary = ref.read(shopTypeProvider) == ShopType.library;
    if (_cart.isEmpty) {
      _showMessage(
          '\u09ac\u09bf\u0995\u09cd\u09b0\u09bf\u09b0 \u099c\u09a8\u09cd\u09af \u0985\u09a8\u09cd\u09a4\u09a4 \u098f\u0995\u099f\u09bf \u09aa\u09a3\u09cd\u09af \u09af\u09cb\u0997 \u0995\u09b0\u09c1\u09a8',);
      return;
    }
    if (isLibrary && _returnDate == null) {
      final isBn = ref.read(appLocalizationsProvider).isBn;
      _showMessage(isBn ? 'ফেরতের তারিখ নির্বাচন করুন' : 'Select a return date');
      return;
    }
    final discountCents = _parseCents(_discountController.text);
    final paidCents = _parseCents(_paidController.text);
    if (discountCents == null || discountCents < 0) {
      _showMessage(
          '\u09b8\u09a0\u09bf\u0995 \u099b\u09be\u09dc\u09c7\u09b0 \u09aa\u09b0\u09bf\u09ae\u09be\u09a3 \u09b2\u09bf\u0996\u09c1\u09a8',);
      return;
    }
    if (discountCents > _subtotalCents) {
      _showMessage(
          '\u099b\u09be\u09dc \u09ae\u09cb\u099f \u09ae\u09c2\u09b2\u09cd\u09af\u09c7\u09b0 \u09ac\u09c7\u09b6\u09bf \u09b9\u09a4\u09c7 \u09aa\u09be\u09b0\u09c7 \u09a8\u09be',);
      return;
    }
    if (paidCents == null || paidCents < 0) {
      _showMessage(
          '\u09b8\u09a0\u09bf\u0995 \u099c\u09ae\u09be\u09b0 \u09aa\u09b0\u09bf\u09ae\u09be\u09a3 \u09b2\u09bf\u0996\u09c1\u09a8',);
      return;
    }
    final payableCents = _subtotalCents - discountCents;
    if (paidCents > payableCents) {
      _showMessage(
          '\u099c\u09ae\u09be\u09b0 \u09aa\u09b0\u09bf\u09ae\u09be\u09a3 \u09ae\u09cb\u099f \u09aa\u09cd\u09b0\u09a6\u09c7\u09df \u099f\u09be\u0995\u09be\u09b0 \u099a\u09c7\u09df\u09c7 \u09ac\u09c7\u09b6\u09bf \u09b9\u09a4\u09c7 \u09aa\u09be\u09b0\u09c7 \u09a8\u09be',);
      return;
    }

    final request = SaleRequest(
      items: _cart.values
          .map((line) => SaleRequestItem(
                productId: line.product.id,
                quantity: line.quantityCents / 100,
                unitPrice: line.product.sellingPrice,
              ),)
          .toList(growable: false),
      discount: discountCents / 100,
      payments: paidCents == 0
          ? const []
          : [
              SaleRequestPayment(
                  amount: paidCents / 100, paymentMethod: _paymentMethod,),
            ],
      returnDate: isLibrary ? _returnDate : null,
    );

    final succeeded =
        await ref.read(salesProvider.notifier).processSale(request);
    if (!mounted) return;
    final result = ref.read(salesProvider);
    if (succeeded) {
      final isBn = ref.read(appLocalizationsProvider).isBn;
      _showMessage(
        isLibrary
            ? (isBn ? 'বই ইস্যু সফল হয়েছে' : 'Book issued successfully')
            : result.successMessage ??
                '\u09ac\u09bf\u0995\u09cd\u09b0\u09df \u09b8\u09ab\u09b2\u09ad\u09be\u09ac\u09c7 \u09b8\u09ae\u09cd\u09aa\u09a8\u09cd\u09a8 \u09b9\u09df\u09c7\u099b\u09c7',
        isError: false,
      );
      setState(() {
        _cart.clear();
        _discountController.text = '0.00';
        _paidAmountEdited = false;
        _returnDate = null;
      });
      _syncDefaultPaidAmount();
      ref.read(productProvider.notifier).refreshProducts();
      Navigator.of(context).pop(true);
    } else {
      _showMessage(
          result.error ??
              '\u09ac\u09bf\u0995\u09cd\u09b0\u09df \u09b8\u09ae\u09cd\u09aa\u09a8\u09cd\u09a8 \u0995\u09b0\u09be \u09af\u09be\u09df\u09a8\u09bf',);
    }
  }

  Future<void> _chooseReturnDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final isBn = ref.read(appLocalizationsProvider).isBn;
    final picked = await showDatePicker(
      context: context,
      initialDate: _returnDate ?? today.add(const Duration(days: 14)),
      firstDate: today,
      lastDate: DateTime(today.year + 3),
      helpText: isBn ? 'ফেরতের তারিখ নির্বাচন করুন' : 'Select return date',
    );
    if (picked != null && mounted) setState(() => _returnDate = picked);
  }

  void _showMessage(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
      ),);
  }

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final salesState = ref.watch(salesProvider);
    final shopType = ref.watch(shopTypeProvider);
    final isLibrary = shopType == ShopType.library;
    final isBn = ref.watch(appLocalizationsProvider).isBn;
    final showFefo = shopType == ShopType.general || shopType == ShopType.pharmacy;
    final products = _visibleProducts(productState.products);

    return Scaffold(
      appBar: AppBar(
        title: Text(isLibrary
            ? (isBn ? 'বই ইস্যু করুন' : 'Issue Book')
            : (isBn ? 'নতুন বিক্রয়' : 'New Sale'),),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                  '\u09aa\u09a3\u09cd\u09af \u0996\u09c1\u0981\u099c\u09c1\u09a8',),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText:
                      '\u09aa\u09a3\u09cd\u09af\u09c7\u09b0 \u09a8\u09be\u09ae, SKU \u09ac\u09be \u09ac\u09be\u09b0\u0995\u09cb\u09a1 \u09b2\u09bf\u0996\u09c1\u09a8',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '\u09ae\u09c1\u099b\u09c1\u09a8',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),),
                ),
              ),
              const SizedBox(height: 8),
              _buildProducts(productState, products,
                  showFefo: showFefo, isLibrary: isLibrary, isBn: isBn,),
              const SizedBox(height: 18),
              _sectionTitle('\u0995\u09be\u09b0\u09cd\u099f (${_cart.length})'),
              const SizedBox(height: 8),
              if (_cart.isEmpty)
                _emptyCart()
              else
                ..._cart.values.map(_cartItem),
              const SizedBox(height: 12),
              _buildSummary(),
              if (isLibrary) ...[
                const SizedBox(height: 12),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_available, color: AppColors.primary),
                    title: Text(isBn ? 'ফেরতের তারিখ *' : 'Return date *'),
                    subtitle: Text(_returnDate == null
                        ? (isBn ? 'তারিখ নির্বাচন করুন' : 'Choose a date')
                        : _formatDate(_returnDate!, isBn),),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: salesState.isLoading ? null : _chooseReturnDate,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _sectionTitle('\u09aa\u09c7\u09ae\u09c7\u09a8\u09cd\u099f'),
              const SizedBox(height: 8),
              _buildPaymentSection(),
              if (salesState.error != null) ...[
                const SizedBox(height: 10),
                Text(salesState.error!,
                    style: const TextStyle(color: AppColors.error),),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            gradient: AppColors.warningGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.28),
                  blurRadius: 16,
                  offset: const Offset(0, 7),),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: salesState.isLoading ? null : _confirmSale,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (salesState.isLoading)
                    const SizedBox.square(
                        dimension: 21,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,),)
                  else
                    const Icon(Icons.point_of_sale_rounded,
                        color: Colors.white,),
                  const SizedBox(width: 10),
                  Text(
                    isLibrary
                        ? (isBn ? 'ইস্যু নিশ্চিত করুন' : 'Confirm Issue')
                        : salesState.isLoading
                        ? '\u09ac\u09bf\u0995\u09cd\u09b0\u09df \u09aa\u09cd\u09b0\u0995\u09cd\u09b0\u09bf\u09df\u09be\u09a7\u09c0\u09a8...'
                        : '\u09ac\u09bf\u0995\u09cd\u09b0\u09df \u09a8\u09bf\u09b6\u09cd\u099a\u09bf\u09a4 \u0995\u09b0\u09c1\u09a8',
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProducts(ProductState state, List<ProductModel> products,
      {required bool showFefo,
      required bool isLibrary,
      required bool isBn,}) {
    if (state.isLoading && state.products.isEmpty) {
      return const SizedBox(
          height: 150, child: Center(child: CircularProgressIndicator()),);
    }
    if (state.error != null && state.products.isEmpty) {
      return _InfoCard(
        icon: Icons.error_outline,
        message: state.error!,
        actionLabel:
            '\u0986\u09ac\u09be\u09b0 \u099a\u09c7\u09b7\u09cd\u099f\u09be \u0995\u09b0\u09c1\u09a8',
        onAction: () => ref.read(productProvider.notifier).loadProducts(),
      );
    }
    if (products.isEmpty) {
      return const _InfoCard(
          icon: Icons.inventory_2_outlined,
          message:
              '\u0995\u09cb\u09a8\u09cb \u09aa\u09a3\u09cd\u09af \u09aa\u09be\u0993\u09df\u09be \u09af\u09be\u09df\u09a8\u09bf',);
    }

    final maxHeight =
        (MediaQuery.sizeOf(context).height * 0.28).clamp(150.0, 250.0);
    return Container(
      height: maxHeight,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        itemCount: products.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final product = products[index];
          final inCart = _cart[product.id]?.quantityCents ?? 0;
          final stockCents = _toQuantityCents(product.totalStock);
          final canAdd = inCart + 100 <= stockCents;
          // Feature 2: wrap in Consumer so each tile independently watches
          // its own FEFO hint without rebuilding the whole list.
          return Consumer(
            builder: (ctx, watchRef, _) {
              final docId = product.docId ?? '';
              final fefoAsync = docId.isNotEmpty
                  && showFefo
                  ? watchRef.watch(_fefoHintProvider(docId))
                  : const AsyncData<DateTime?>(null);
              final earliestExpiry = fefoAsync.valueOrNull;

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    dense: true,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 2),
                    title: Text(product.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis,),
                    subtitle: Text(
                        isLibrary
                            ? '${product.author ?? (isBn ? 'বই' : 'Book')}${product.isbn == null ? '' : ' · ISBN ${product.isbn}'} · ৳${product.sellingPrice.toStringAsFixed(2)} · ${isBn ? 'স্টক' : 'Stock'} ${_formatQuantity(stockCents)} ${product.unit}'
                            : '৳${product.sellingPrice.toStringAsFixed(2)} · স্টক ${_formatQuantity(stockCents)} ${product.unit}',),
                    trailing: IconButton.filled(
                      tooltip: 'কার্টে যোগ করুন',
                      style: IconButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white,),
                      onPressed: canAdd ? () => _addProduct(product) : null,
                      icon: const Icon(Icons.add),
                    ),
                  ),
                  // FEFO hint badge — only shown when a dated batch exists.
                  if (showFefo && earliestExpiry != null)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: 6, right: 6, bottom: 4,),
                      child: _FefoBadge(expiryDate: earliestExpiry),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _cartItem(_SaleCartLine line) {
    final lineTotal = _lineTotalCents(
        line.quantityCents, _toCents(line.product.sellingPrice),);
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),),
                  const SizedBox(height: 3),
                  Text('\u09F3${_formatMoney(lineTotal)}',
                      style: const TextStyle(color: AppColors.textSecondary),),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '\u098f\u0995 \u0995\u09ae\u09be\u09a8',
              onPressed: () => _changeQuantity(line, -100),
              icon: const Icon(Icons.remove_circle_outline),
            ),
            InkWell(
              onTap: () => _editQuantity(line),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                    '${_formatQuantity(line.quantityCents)} ${line.product.unit}',
                    style: const TextStyle(fontWeight: FontWeight.w600),),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: '\u098f\u0995 \u09ac\u09be\u09dc\u09be\u09a8',
              onPressed: () => _changeQuantity(line, 100),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyCart() => const _InfoCard(
        icon: Icons.shopping_cart_outlined,
        message:
            '\u09ac\u09bf\u0995\u09cd\u09b0\u09bf\u09b0 \u099c\u09a8\u09cd\u09af \u09aa\u09a3\u09cd\u09af \u09af\u09cb\u0997 \u0995\u09b0\u09c1\u09a8',
      );

  Widget _buildSummary() => Card(
        color: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _summaryRow('\u09b8\u09be\u09ac\u099f\u09cb\u099f\u09be\u09b2',
                  '\u09F3${_formatMoney(_subtotalCents)}',),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(child: Text('\u099b\u09be\u09dc')),
                  SizedBox(
                    width: 130,
                    child: TextField(
                      controller: _discountController,
                      textAlign: TextAlign.end,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [_moneyInputFormatter],
                      decoration: const InputDecoration(
                        prefixText: '\u09F3 ',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              _summaryRow(
                  '\u09ae\u09cb\u099f \u09aa\u09cd\u09b0\u09a6\u09c7\u09df',
                  '\u09F3${_formatMoney(_payableCents)}',
                  bold: true,),
            ],
          ),
        ),
      );

  Widget _buildPaymentSection() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  labelText:
                      '\u09aa\u09c7\u09ae\u09c7\u09a8\u09cd\u099f \u09aa\u09a6\u09cd\u09a7\u09a4\u09bf',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'cash', child: Text('\u09a8\u0997\u09a6 (Cash)'),),
                  DropdownMenuItem(
                      value: 'bkash',
                      child: Text('\u09ac\u09bf\u0995\u09be\u09b6 (Bkash)'),),
                  DropdownMenuItem(
                      value: 'nagad',
                      child: Text('\u09a8\u0997\u09a6 (Nagad)'),),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _paymentMethod = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _paidController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_moneyInputFormatter],
                onChanged: (_) => _paidAmountEdited = true,
                decoration: const InputDecoration(
                  labelText: '\u099c\u09ae\u09be \u099f\u09be\u0995\u09be',
                  prefixText: '\u09F3 ',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _summaryRow(String label, String value, {bool bold = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  bold ? const TextStyle(fontWeight: FontWeight.bold) : null,),
          Text(value,
              style: bold
                  ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)
                  : null,),
        ],
      );

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,),
      );

  String _formatDate(DateTime date, bool isBn) {
    var value = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    if (isBn) {
      const latin = '0123456789';
      const bengali = '০১২৩৪৫৬৭৮৯';
      for (var i = 0; i < latin.length; i++) {
        value = value.replaceAll(latin[i], bengali[i]);
      }
    }
    return value;
  }
}

class _SaleCartLine {

  const _SaleCartLine({required this.product, required this.quantityCents});
  final ProductModel product;
  final int quantityCents;

  _SaleCartLine copyWith({int? quantityCents}) => _SaleCartLine(
        product: product,
        quantityCents: quantityCents ?? this.quantityCents,
      );
}

class _InfoCard extends StatelessWidget {

  const _InfoCard(
      {required this.icon,
      required this.message,
      this.actionLabel,
      this.onAction,});
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<IconData>('icon', icon));
    properties.add(StringProperty('message', message));
    properties.add(StringProperty('actionLabel', actionLabel));
    properties.add(ObjectFlagProperty<VoidCallback?>.has('onAction', onAction));
  }
}

// =============================================================================
// Feature 2: FEFO badge widget
// =============================================================================

/// Shows a compact orange hint strip: "এই ব্যাচটি আগে বিক্রি করুন (মেয়াদ: DD/MM/YY)"
class _FefoBadge extends StatelessWidget {
  const _FefoBadge({required this.expiryDate});
  final DateTime expiryDate;

  @override
  Widget build(BuildContext context) {
    final d = expiryDate;
    final dateStr =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.schedule_rounded,
              size: 12, color: AppColors.accent,),
          const SizedBox(width: 4),
          Text(
            'এই ব্যাচটি আগে বিক্রি করুন (মেয়াদ: $dateStr)',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.accentDark,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<DateTime>('expiryDate', expiryDate));
  }
}

// =============================================================================
// Money / quantity helpers (unchanged)
// =============================================================================
final _moneyInputFormatter =
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'));

// =============================================================================
// Feature 2: FEFO hint provider
// =============================================================================

/// Fetches the earliest non-expired expiry date for a product's active batches.
/// Returns null if no dated batches exist (no hint needed).
/// Uses a family provider keyed by the Firestore product doc id (String).
final _fefoHintProvider =
    FutureProvider.family<DateTime?, String>((ref, productDocId) async {
  if (productDocId.isEmpty) return null;
  try {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await FirebaseFirestore.instance
        .collection('shops')
        .doc(uid)
        .collection('batches')
        .where('product_id', isEqualTo: productDocId)
        .get();

    DateTime? earliest;
    var eligibleBatchCount = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final active = data['is_active'] as bool? ?? true;
      final qty = (data['quantity'] as num?)?.toDouble() ?? 0;
      if (!active || qty <= 0) continue;
      final raw = data['expiry_date'];
      DateTime? expiry;
      if (raw is Timestamp) expiry = raw.toDate();
      if (expiry == null) continue;
      // Skip already-expired batches — the FEFO hint is about "sell this first"
      // among current stock, not about promoting expired goods.
      final today = DateTime.now();
      if (expiry.isBefore(DateTime(today.year, today.month, today.day))) {
        continue;
      }
      eligibleBatchCount++;
      if (earliest == null || expiry.isBefore(earliest)) earliest = expiry;
    }
    // A single batch needs no allocation hint; show the badge when there is a
    // choice to make and FEFO identifies which expiry should be consumed first.
    return eligibleBatchCount > 1 ? earliest : null;
  } catch (_) {
    return null;
  }
});

int _toCents(double amount) => (amount * 100).round();

int _toQuantityCents(double quantity) => (quantity * 100).round();

int _lineTotalCents(int quantityCents, int unitPriceCents) =>
    (quantityCents * unitPriceCents + 50) ~/ 100;

int? _parseCents(String input) {
  final match = RegExp(r'^(\d+)(?:\.(\d{0,2}))?$').firstMatch(input.trim());
  if (match == null) return null;
  final whole = int.tryParse(match.group(1)!);
  final fraction = int.tryParse((match.group(2) ?? '').padRight(2, '0')) ?? 0;
  return whole == null ? null : whole * 100 + fraction;
}

String _formatMoney(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

String _formatQuantity(int quantityCents) {
  final whole = quantityCents ~/ 100;
  final fraction = quantityCents % 100;
  if (fraction == 0) return '$whole';
  if (fraction % 10 == 0) return '$whole.${fraction ~/ 10}';
  return '$whole.${fraction.toString().padLeft(2, '0')}';
}
