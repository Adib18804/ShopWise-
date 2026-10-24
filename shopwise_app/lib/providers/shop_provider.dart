import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/shop_model.dart';
import '../services/shop_service.dart';
import '../core/network/api_exception.dart';

/// Shop state
class ShopState {
  final ShopModel? shop;
  final bool isLoading;
  final bool hasShop;
  final String? error;

  ShopState({
    this.shop,
    this.isLoading = false,
    this.hasShop = false,
    this.error,
  });

  ShopState copyWith({
    ShopModel? shop,
    bool? isLoading,
    bool? hasShop,
    String? error,
  }) {
    return ShopState(
      shop: shop ?? this.shop,
      isLoading: isLoading ?? this.isLoading,
      hasShop: hasShop ?? this.hasShop,
      error: error,
    );
  }

  ShopState clearError() {
    return ShopState(
      shop: shop,
      isLoading: isLoading,
      hasShop: hasShop,
      error: null,
    );
  }
}

/// Shop state notifier
class ShopNotifier extends StateNotifier<ShopState> {
  final ShopService _shopService;

  ShopNotifier(this._shopService) : super(ShopState());

  /// Initialize shop state (check if user has shop and load it)
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true);

    try {
      final hasShop = await _shopService.checkShop();

      if (hasShop) {
        final shop = await _shopService.getMyShop();
        state = ShopState(
          shop: shop,
          hasShop: true,
          isLoading: false,
        );
      } else {
        state = ShopState(
          hasShop: false,
          isLoading: false,
        );
      }
    } catch (e) {
      state = ShopState(
        hasShop: false,
        isLoading: false,
        error: e is ApiException ? e.message : 'Failed to load shop',
      );
    }
  }

  /// Create new shop
  Future<bool> createShop({
    required String shopName,
    required String address,
    required String phone,
    String currency = 'BDT',
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final shop = await _shopService.createShop(
        shopName: shopName,
        address: address,
        phone: phone,
        currency: currency,
      );

      state = ShopState(
        shop: shop,
        hasShop: true,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ApiException ? e.message : 'Failed to create shop',
      );
      return false;
    }
  }

  /// Load user's shop
  Future<void> loadShop() async {
    state = state.copyWith(isLoading: true);

    try {
      final shop = await _shopService.getMyShop();
      state = ShopState(
        shop: shop,
        hasShop: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ApiException ? e.message : 'Failed to load shop',
      );
    }
  }

  /// Update shop
  Future<bool> updateShop({
    String? shopName,
    String? address,
    String? phone,
    String? currency,
  }) async {
    if (state.shop == null) {
      state = state.copyWith(error: 'No shop found');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final updatedShop = await _shopService.updateShop(
        shopId: state.shop!.id,
        shopName: shopName,
        address: address,
        phone: phone,
        currency: currency,
      );

      state = ShopState(
        shop: updatedShop,
        hasShop: true,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ApiException ? e.message : 'Failed to update shop',
      );
      return false;
    }
  }

  /// Delete shop
  Future<bool> deleteShop() async {
    if (state.shop == null) {
      state = state.copyWith(error: 'No shop found');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _shopService.deleteShop(state.shop!.id);

      state = ShopState(
        hasShop: false,
        isLoading: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e is ApiException ? e.message : 'Failed to delete shop',
      );
      return false;
    }
  }

  /// Clear error
  void clearError() {
    state = state.clearError();
  }
}

/// Shop service provider
final shopServiceProvider = Provider<ShopService>((ref) {
  return ShopService();
});

/// Shop state provider
final shopProvider = StateNotifierProvider<ShopNotifier, ShopState>((ref) {
  final shopService = ref.watch(shopServiceProvider);
  return ShopNotifier(shopService);
});
