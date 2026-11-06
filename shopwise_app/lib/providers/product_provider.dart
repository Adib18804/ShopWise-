import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import 'category_provider.dart';

/// Product state (unchanged contract).
class ProductState {
  final List<ProductModel> products;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;
  final String? searchQuery;
  final int? selectedCategoryId;

  ProductState({
    this.products = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
    this.searchQuery,
    this.selectedCategoryId,
  });

  ProductState copyWith({
    List<ProductModel>? products,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
    String? searchQuery,
    int? selectedCategoryId,
    bool clearCategory = false,
  }) {
    return ProductState(
      products: products ?? this.products,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
    );
  }

  ProductState clearError() {
    return ProductState(
      products: products,
      isLoading: isLoading,
      isRefreshing: isRefreshing,
      error: null,
      searchQuery: searchQuery,
      selectedCategoryId: selectedCategoryId,
    );
  }

  /// Get filtered products
  List<ProductModel> get filteredProducts {
    return products;
  }

  /// Get low stock products
  List<ProductModel> get lowStockProducts {
    return products.where((product) => product.isLowStock).toList();
  }

  /// Get out of stock products
  List<ProductModel> get outOfStockProducts {
    return products.where((product) => product.isOutOfStock).toList();
  }
}

/// Product state notifier backed by a Firestore real-time stream.
///
/// [loadProducts] subscribes to [ProductService.productsStream] once; search
/// and category filters are applied client-side on every snapshot, so the list
/// stays live without extra round-trips. CRUD methods write to Firestore and
/// let the stream refresh the list automatically.
class ProductNotifier extends StateNotifier<ProductState> {
  final ProductService _productService;
  final Ref _ref;

  StreamSubscription<List<ProductModel>>? _sub;
  List<ProductModel> _all = const [];
  String? _search;
  int? _categoryId;

  ProductNotifier(this._productService, this._ref) : super(ProductState());

  /// Load products. On first call this shows a loading spinner until the first
  /// snapshot; subsequent calls just re-filter the live data instantly.
  Future<void> loadProducts({
    String? search,
    int? categoryId,
  }) async {
    _search = search;
    _categoryId = categoryId;

    final needsSubscribe = _sub == null;
    if (needsSubscribe) {
      state = state.copyWith(
        isLoading: _all.isEmpty,
        error: null,
        searchQuery: search,
        selectedCategoryId: categoryId,
        clearCategory: categoryId == null,
      );
      await _ensureSubscribed();
      // The first snapshot will call _applyFilter() with the fresh data.
    } else {
      state = state.copyWith(
        error: null,
        searchQuery: search,
        selectedCategoryId: categoryId,
        clearCategory: categoryId == null,
      );
      _applyFilter();
    }
  }

  /// Refresh products
  Future<void> refreshProducts() async {
    state = state.copyWith(isRefreshing: true, error: null);
    await _sub?.cancel();
    _sub = null;
    await _ensureSubscribed();
  }

  /// Search products
  Future<void> searchProducts(String query) async {
    await loadProducts(
      search: query.isEmpty ? null : query,
      categoryId: _categoryId,
    );
  }

  /// Filter by category
  Future<void> filterByCategory(int? categoryId) async {
    await loadProducts(search: _search, categoryId: categoryId);
  }

  /// Clear filters
  Future<void> clearFilters() async {
    await loadProducts();
  }

  /// Create product
  Future<bool> createProduct({
    required int categoryId,
    required String name,
    String? sku,
    String? barcode,
    required String unit,
    required double sellingPrice,
    required double defaultPurchasePrice,
    double minimumStock = 0,
    int targetStockDays = 7,
  }) async {
    try {
      await _productService.createProduct(
        categoryId: categoryId,
        name: name,
        sku: sku,
        barcode: barcode,
        unit: unit,
        sellingPrice: sellingPrice,
        defaultPurchasePrice: defaultPurchasePrice,
        minimumStock: minimumStock,
        targetStockDays: targetStockDays,
      );
      // The real-time stream refreshes the list automatically.
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e is ApiException ? e.message : 'পণ্য যোগ করা যায়নি',
      );
      return false;
    }
  }

  /// Update product
  Future<bool> updateProduct({
    required int id,
    int? categoryId,
    String? name,
    String? sku,
    String? barcode,
    String? unit,
    double? sellingPrice,
    double? defaultPurchasePrice,
    double? minimumStock,
    int? targetStockDays,
  }) async {
    try {
      await _productService.updateProduct(
        id: id,
        categoryId: categoryId,
        name: name,
        sku: sku,
        barcode: barcode,
        unit: unit,
        sellingPrice: sellingPrice,
        defaultPurchasePrice: defaultPurchasePrice,
        minimumStock: minimumStock,
        targetStockDays: targetStockDays,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e is ApiException ? e.message : 'পণ্য আপডেট করা যায়নি',
      );
      return false;
    }
  }

  /// Delete product
  Future<bool> deleteProduct(int id) async {
    try {
      await _productService.deleteProduct(id);
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e is ApiException ? e.message : 'পণ্য মুছতে সমস্যা হয়েছে',
      );
      return false;
    }
  }

  /// Load low stock products (one-time; cancels the live stream).
  Future<void> loadLowStockProducts() async {
    await _sub?.cancel();
    _sub = null;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final products = await _productService.getLowStockProducts();
      _all = products;
      state = ProductState(products: _enrich(products), isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ApiException ? e.message : 'স্টক তথ্য লোড করা যায়নি',
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.clearError();
  }

  // ---------------------------------------------------------------------------
  // Real-time plumbing
  // ---------------------------------------------------------------------------

  Future<void> _ensureSubscribed() async {
    if (_sub != null) return;
    _sub = _productService.productsStream().listen(
      (list) {
        _all = list;
        _applyFilter();
      },
      onError: (Object error) {
        state = state.copyWith(
          isLoading: false,
          isRefreshing: false,
          error: error is ApiException
              ? error.message
              : 'পণ্য তথ্য লোড করা যায়নি',
        );
      },
    );
  }

  void _applyFilter() {
    var filtered = _all;
    if (_categoryId != null) {
      filtered = filtered.where((p) => p.categoryId == _categoryId).toList();
    }
    if (_search != null && _search!.trim().isNotEmpty) {
      final q = _search!.trim().toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(q) ||
            (p.sku?.toLowerCase().contains(q) ?? false) ||
            (p.barcode?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
    state = ProductState(
      products: _enrich(filtered),
      isLoading: false,
      isRefreshing: false,
      searchQuery: _search,
      selectedCategoryId: _categoryId,
    );
  }

  /// Attaches the category name to each product so cards show the real category
  /// instead of "অজানা" (no server-side join in the prototype).
  List<ProductModel> _enrich(List<ProductModel> products) {
    final cats = _ref.read(categoryProvider).categories;
    if (cats.isEmpty) return products;
    final byId = <int, String>{for (final c in cats) c.id: c.name};
    return products.map((p) {
      if (p.categoryId == null) return p;
      final name = byId[p.categoryId!];
      if (name == null) return p;
      return p.copyWith(category: CategoryInfo(id: p.categoryId!, name: name));
    }).toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

/// Product service provider
final productServiceProvider = Provider<ProductService>((ref) {
  return ProductService();
});

/// Product state provider
final productProvider =
    StateNotifierProvider<ProductNotifier, ProductState>((ref) {
  final productService = ref.watch(productServiceProvider);
  return ProductNotifier(productService, ref);
});
