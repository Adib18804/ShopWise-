import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/product_provider.dart';
import '../../../providers/category_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'product_form_screen.dart';
import 'product_detail_screen.dart';

/// Products list screen
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    // Load products and categories on init
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
                onTap: () => Navigator.of(context).pop(null),
              ),
              ...categories.map((category) => ListTile(
                    title: Text(category.name),
                    leading: Radio<int?>(
                      value: category.id,
                      groupValue: currentCategoryId,
                      onChanged: (value) => Navigator.of(context).pop(value),
                    ),
                    onTap: () => Navigator.of(context).pop(category.id),
                  )),
            ],
          ),
        ),
      ),
    );

    if (selected != null || selected == null && currentCategoryId != null) {
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

  @override
  Widget build(BuildContext context) {
    final productState = ref.watch(productProvider);
    final categoryState = ref.watch(categoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'পণ্য খুঁজুন...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: _handleSearch,
              )
            : const Text('পণ্য'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
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
            icon: const Icon(Icons.filter_list),
            onPressed: _showCategoryFilter,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          if (productState.selectedCategoryId != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Text(
                    'ফিল্টার: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Chip(
                    label: Text(
                      categoryState.categories
                              .firstWhere(
                                (c) => c.id == productState.selectedCategoryId,
                                orElse: () => categoryState.categories.first,
                              )
                              .name,
                    ),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      ref.read(productProvider.notifier).clearFilters();
                    },
                  ),
                ],
              ),
            ),
          ],

          // Products list
          Expanded(
            child: productState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : productState.products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inventory_2_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'কোন পণ্য নেই',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'নতুন পণ্য যোগ করুন',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _handleRefresh,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: productState.products.length,
                          itemBuilder: (context, index) {
                            final product = productState.products[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      product.isOutOfStock
                                          ? AppColors.error.withOpacity(0.1)
                                          : product.isLowStock
                                              ? Colors.orange.withOpacity(0.1)
                                              : AppColors.primary
                                                  .withOpacity(0.1),
                                  child: Icon(
                                    Icons.inventory_2,
                                    color: product.isOutOfStock
                                        ? AppColors.error
                                        : product.isLowStock
                                            ? Colors.orange
                                            : AppColors.primary,
                                  ),
                                ),
                                title: Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text(
                                      product.category?.name ?? 'অজানা',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'স্টক: ${product.formattedTotalStock} ${_getUnitLabel(product.unit)}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: product.isOutOfStock
                                                ? AppColors.error
                                                : product.isLowStock
                                                    ? Colors.orange
                                                    : Colors.green,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (product.isLowStock &&
                                            !product.isOutOfStock) ...[
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.warning,
                                            size: 16,
                                            color: Colors.orange,
                                          ),
                                        ],
                                        if (product.isOutOfStock) ...[
                                          const SizedBox(width: 8),
                                          const Icon(
                                            Icons.cancel,
                                            size: 16,
                                            color: AppColors.error,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) =>
                                          ProductDetailScreen(product: product),
                                    ),
                                  );
                                },
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
              builder: (_) => const ProductFormScreen(),
            ),
          );

          if (result == true) {
            _handleRefresh();
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
      ),
    );
  }
}
