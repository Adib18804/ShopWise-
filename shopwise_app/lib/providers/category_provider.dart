import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category_model.dart';
import '../services/category_service.dart';
import '../core/network/api_exception.dart';

/// Category state
class CategoryState {
  final List<CategoryModel> categories;
  final bool isLoading;
  final bool isRefreshing;
  final String? error;

  CategoryState({
    this.categories = const [],
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  CategoryState copyWith({
    List<CategoryModel>? categories,
    bool? isLoading,
    bool? isRefreshing,
    String? error,
  }) {
    return CategoryState(
      categories: categories ?? this.categories,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error,
    );
  }

  CategoryState clearError() {
    return CategoryState(
      categories: categories,
      isLoading: isLoading,
      isRefreshing: isRefreshing,
      error: null,
    );
  }
}

/// Category state notifier
class CategoryNotifier extends StateNotifier<CategoryState> {
  final CategoryService _categoryService;

  CategoryNotifier(this._categoryService) : super(CategoryState());

  /// Load categories
  Future<void> loadCategories() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final categories = await _categoryService.getCategories();
      state = CategoryState(
        categories: categories,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ApiException ? e.message : 'Failed to load categories',
      );
    }
  }

  /// Refresh categories
  Future<void> refreshCategories() async {
    state = state.copyWith(isRefreshing: true, error: null);

    try {
      final categories = await _categoryService.getCategories();
      state = CategoryState(
        categories: categories,
        isRefreshing: false,
      );
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: e is ApiException ? e.message : 'Failed to refresh categories',
      );
    }
  }

  /// Create category
  Future<bool> createCategory({
    required String name,
    String? description,
  }) async {
    try {
      final category = await _categoryService.createCategory(
        name: name,
        description: description,
      );

      // Add to list
      state = state.copyWith(
        categories: [...state.categories, category],
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        error: e is ApiException ? e.message : 'Failed to create category',
      );
      return false;
    }
  }

  /// Update category
  Future<bool> updateCategory({
    required int id,
    String? name,
    String? description,
  }) async {
    try {
      final updatedCategory = await _categoryService.updateCategory(
        id: id,
        name: name,
        description: description,
      );

      // Update in list
      final categories = state.categories.map((category) {
        if (category.id == id) {
          return updatedCategory;
        }
        return category;
      }).toList();

      state = state.copyWith(categories: categories);

      return true;
    } catch (e) {
      state = state.copyWith(
        error: e is ApiException ? e.message : 'Failed to update category',
      );
      return false;
    }
  }

  /// Delete category
  Future<bool> deleteCategory(int id) async {
    try {
      await _categoryService.deleteCategory(id);

      // Remove from list
      final categories =
          state.categories.where((category) => category.id != id).toList();

      state = state.copyWith(categories: categories);

      return true;
    } catch (e) {
      state = state.copyWith(
        error: e is ApiException ? e.message : 'Failed to delete category',
      );
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.clearError();
  }
}

/// Category service provider
final categoryServiceProvider = Provider<CategoryService>((ref) {
  return CategoryService();
});

/// Category state provider
final categoryProvider =
    StateNotifierProvider<CategoryNotifier, CategoryState>((ref) {
  final categoryService = ref.watch(categoryServiceProvider);
  return CategoryNotifier(categoryService);
});
