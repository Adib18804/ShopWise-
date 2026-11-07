import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/product_model.dart';
import '../../../providers/category_provider.dart';
import '../../../providers/insight_provider.dart';
import '../../../providers/product_provider.dart';
import 'product_detail_screen.dart';
import 'product_form_screen.dart';

// ─── Filter chip enum ────────────────────────────────────────────────────────

enum _StockFilter { all, lowStock, expiringSoon, slowMoving }

extension _StockFilterLabel on _StockFilter {
  String label(bool isBn) => switch (this) {
        _StockFilter.all => isBn ? 'সব' : 'All',
        _StockFilter.lowStock => isBn ? 'কম স্টক' : 'Low Stock',
        _StockFilter.expiringSoon => isBn ? 'মেয়াদ শেষ' : 'Expiring',
        _StockFilter.slowMoving => isBn ? 'ধীরগতি' : 'Slow Moving',
      };
}

// ─── Screen ──────────────────────────────────────────────────────────────────

/// My Stock screen — product list with working filter chips:
/// All · Low Stock · Expiring Soon · Slow Moving
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  bool _showSearch = false;
  _StockFilter _activeFilter = _StockFilter.all;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(productProvider.notifier).loadProducts();
      ref.read(categoryProvider.notifier).loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    await ref.read(productProvider.notifier).refreshProducts();
  }

  void _handleSearch(String query) {
    ref.read(productProvider.notifier).searchProducts(query);
  }

  // ─── Filtering ─────────────────────────────────────────────────────────────

  List<ProductModel> _applyFilter(
    List<ProductModel> all,
    _StockFilter filter,
  ) {
    switch (filter) {
      case _StockFilter.all:
        return all;
      case _StockFilter.lowStock:
        // Low stock = at or below minimum stock threshold.
        return all.where((p) => p.isLowStock).toList();
      case _StockFilter.expiringSoon:
        // Derived from the insight provider's expiry alert product ids.
        final summary = ref.read(insightsProvider).summary;
        if (summary == null) return const <ProductModel>[];
        final expiringIds =
            summary.expiryAlerts.map((e) => e.productId).toSet();
        return all
            .where((p) => expiringIds.contains(p.docId ?? ''))
            .toList();
      case _StockFilter.slowMoving:
        final summary = ref.read(insightsProvider).summary;
        if (summary == null) return [];
        final deadIds =
            summary.deadStockAlerts.map((e) => e.productId).toSet();
        return all
            .where((p) => deadIds.contains(p.docId ?? ''))
            .toList();
    }
  }

  // ─── Category filter dialog (unchanged) ────────────────────────────────────

  Future<void> _showCategoryFilter() async {
    final categories = ref.read(categoryProvider).categories;
    final currentCategoryId = ref.read(productProvider).selectedCategoryId;

    final selected = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ক্যাটাগরি নির্বাচন করুন'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('সব'),
                leading: Radio<int?>(
                  value: null,
                  groupValue: currentCategoryId,
                  onChanged: (value) => Navigator.of(context).pop(value),
                ),
                onTap: () => Navigator.of(context).pop(),
              ),
              ...categories.map((cat) => ListTile(
                    title: Text(cat.name),
                    leading: Radio<int?>(
                      value: cat.id,
                      groupValue: currentCategoryId,
                      onChanged: (v) => Navigator.of(context).pop(v),
                    ),
                    onTap: () => Navigator.of(context).pop(cat.id),
                  ),),
            ],
          ),
        ),
      ),
    );
    if (selected != null || (selected == null && currentCategoryId != null)) {
      ref.read(productProvider.notifier).filterByCategory(selected);
    }
  }

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

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final productState = ref.watch(productProvider);
    final categoryState = ref.watch(categoryProvider);
    // Watch insights so filter chips react when the analysis updates.
    ref.watch(insightsProvider);

    final filteredProducts =
        _applyFilter(productState.products, _activeFilter);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'পণ্য খুঁজুন...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                ),
                style: const TextStyle(
                    color: AppColors.textPrimary, fontSize: 16,),
                onChanged: _handleSearch,
              )
            : const Text('আমার স্টক'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search_rounded),
            color: AppColors.primary,
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchController.clear();
                  ref.read(productProvider.notifier).clearFilters();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            color: AppColors.primary,
            tooltip: 'ক্যাটাগরি',
            onPressed: _showCategoryFilter,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter chips row ─────────────────────────────────────────────
          _FilterChipsBar(
            active: _activeFilter,
            onSelected: (f) => setState(() => _activeFilter = f),
          ),

          // ── Category active chip ─────────────────────────────────────────
          if (productState.selectedCategoryId != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.surfaceVariant,
              child: Row(
                children: [
                  const Text(
                    'ক্যাটাগরি: ',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,),
                  ),
                  InputChip(
                    label: Text(
                      categoryState.categories
                          .firstWhere(
                            (c) => c.id == productState.selectedCategoryId,
                            orElse: () => categoryState.categories.first,
                          )
                          .name,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary,),
                    ),
                    onPressed: () =>
                        ref.read(productProvider.notifier).clearFilters(),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () =>
                        ref.read(productProvider.notifier).clearFilters(),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    side: BorderSide(
                        color: AppColors.primary.withValues(alpha: 0.3),),
                  ),
                ],
              ),
            ),

          // ── Product list ─────────────────────────────────────────────────
          Expanded(
            child: productState.isLoading && productState.products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : filteredProducts.isEmpty
                    ? _EmptyState(filter: _activeFilter)
                    : RefreshIndicator(
                        onRefresh: _handleRefresh,
                        color: AppColors.primary,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                          itemCount: filteredProducts.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return _ProductCard(
                              product: product,
                              unitLabel: _getUnitLabel(product.unit),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      ProductDetailScreen(product: product),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
                builder: (_) => const ProductFormScreen(),),
          );
          if (result ?? false) _handleRefresh();
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

// =============================================================================
// Filter chips bar
// =============================================================================

class _FilterChipsBar extends StatelessWidget {

  const _FilterChipsBar({required this.active, required this.onSelected});
  final _StockFilter active;
  final ValueChanged<_StockFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    // Simplified bilingual — just Bengali for now (matches target audience).
    const isBn = true;
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: _StockFilter.values.map((f) {
          final isActive = f == active;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7,),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  f.label(isBn),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<_StockFilter>('active', active));
    properties.add(ObjectFlagProperty<ValueChanged<_StockFilter>>.has('onSelected', onSelected));
  }
}

// =============================================================================
// Product card
// =============================================================================

class _ProductCard extends StatelessWidget {

  const _ProductCard({
    required this.product,
    required this.unitLabel,
    required this.onTap,
  });
  final ProductModel product;
  final String unitLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = product.isOutOfStock
        ? AppColors.error
        : product.isLowStock
            ? AppColors.warning
            : AppColors.success;

    final statusLabel = product.isOutOfStock
        ? 'স্টক শেষ'
        : product.isLowStock
            ? 'কম স্টক'
            : 'স্বাভাবিক';

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.inventory_2_rounded,
                    color: statusColor, size: 22,),
              ),
              const SizedBox(width: 12),
              // Name + category
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      product.category?.name ?? 'অজানা',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary,),
                    ),
                    // Restock badge (low stock)
                    if (product.isLowStock) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2,),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: AppColors.warning.withValues(alpha: 0.4),),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh_rounded,
                                size: 11, color: AppColors.warning,),
                            SizedBox(width: 3),
                            Text('রিস্টক করুন',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w700,),),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Stock qty + status badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${product.formattedTotalStock} $unitLabel',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: statusColor,),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3,),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColors.textDisabled,),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ProductModel>('product', product));
    properties.add(StringProperty('unitLabel', unitLabel));
    properties.add(ObjectFlagProperty<VoidCallback>.has('onTap', onTap));
  }
}

// =============================================================================
// Empty state
// =============================================================================

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filter});
  final _StockFilter filter;

  @override
  Widget build(BuildContext context) {
    final (icon, title, sub) = switch (filter) {
      _StockFilter.all => (
          Icons.inventory_2_outlined,
          'কোনো পণ্য নেই',
          'নতুন পণ্য যোগ করুন'
        ),
      _StockFilter.lowStock => (
          Icons.warning_amber_rounded,
          'কম স্টকের পণ্য নেই',
          'সব পণ্যের স্টক স্বাভাবিক আছে'
        ),
      _StockFilter.expiringSoon => (
          Icons.schedule_rounded,
          'মেয়াদ-শেষ ঝুঁকি নেই',
          'কোনো পণ্যের মেয়াদ শীঘ্রই শেষ হচ্ছে না'
        ),
      _StockFilter.slowMoving => (
          Icons.hourglass_empty_rounded,
          'ধীরগতির পণ্য নেই',
          'সব পণ্য সক্রিয়ভাবে বিক্রি হচ্ছে'
        ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: AppColors.textDisabled),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,),),
            const SizedBox(height: 6),
            Text(sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textDisabled,),),
          ],
        ),
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<_StockFilter>('filter', filter));
  }
}
