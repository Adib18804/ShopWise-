import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/product_model.dart';
import '../services/product_service.dart';
import '../core/network/api_exception.dart';

/// Product state
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

/// Product state notifier
class ProductNotifier extends StateNotifier<ProductState> {
  final ProductService _productService;

  ProductNotifier(this._productService) : super(ProductState());

  /// Load products
  Future<void> loadProducts({
    String? search,
    int? categoryId,
  }) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      searchQuery: search,
      selectedCategoryId: categoryId,
      clearCategory: categoryId == null,
    );

    try {
      final products = await _productService.getProducts(
        search: search,
        categoryId: categoryId,
      );

      state = ProductState(
        products: products,
        isLoading: false,
        searchQuery: search,
        selectedCategoryId: categoryId,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ApiException ? e.message : 'Failed to load products',
      );
    }
  }

  /// Refresh products
  Future<void> refreshProducts() async {
    state = state.copyWith(isRefreshing: true, error: null);

    try {
      final products = await _productService.getProducts(
        search: state.searchQuery,
        categoryId: state.selectedCategoryId,
      );

      state = ProductState(
        products: products,
        isRefreshing: false,
        searchQuery: state.searchQuery,
        selectedCategoryId: state.selectedCategoryId,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: e is ApiException ? e.message : 'Failed to refresh products',
      );
    }
  }

  /// Search products
  Future<void> searchProducts(String query) async {
    await loadProducts(
      search: query.isEmpty ? null : query,
      categoryId: state.selectedCategoryId,
    );
  }

  /// Filter by category
  Future<void> filterByCategory(int? categoryId) async {
    await loadProducts(
      search: state.searchQuery,
      categoryId: categoryId,
    );
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
      final product = await _productService.createProduct(
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

      // Add to list
      state = state.copyWith(
        products: [...state.products, product],
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        error: e is ApiException ? e.message : 'Failed to create product',
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
      final updatedProduct = await _productService.updateProduct(
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

      // Update in list
      final products = state.products.map((product) {
        if (product.id == id) {
          return updatedProduct;
        }
        return product;
      }).toList();

      state = state.copyWith(products: products);

      return true;
    } catch (e) {
      state = state.copyWith(
        error: e is ApiException ? e.message : 'Failed to update product',
      );
      return false;
    }
  }

  /// Delete product
  Future<bool> deleteProduct(int id) async {
    try {
      await _productService.deleteProduct(id);

      // Remove from list
      final products =
          state.products.where((product) => product.id != id).toList();

      state = state.copyWith(products: products);

      return true;
    } catch (e) {
      state = state.copyWith(
        error: e is ApiException ? e.message : 'Failed to delete product',
      );
      return false;
    }
  }

  /// Load low stock products
  Future<void> loadLowStockProducts() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final products = await _productService.getLowStockProducts();

      state = ProductState(
        products: products,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error:
            e is ApiException ? e.message : 'Failed to load low stock products',
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.clearError();
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
  return ProductNotifier(productService);
});
