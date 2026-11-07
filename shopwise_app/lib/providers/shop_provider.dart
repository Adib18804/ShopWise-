import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/shop_model.dart';
import '../services/shop_service.dart';

/// Shop state
class ShopState {

  ShopState({
    this.shop,
    this.isLoading = false,
    this.hasShop = false,
    this.error,
  });
  final ShopModel? shop;
  final bool isLoading;
  final bool hasShop;
  final String? error;

  ShopState copyWith({
    ShopModel? shop,
    bool? isLoading,
    bool? hasShop,
    String? error,
  }) => ShopState(
      shop: shop ?? this.shop,
      isLoading: isLoading ?? this.isLoading,
      hasShop: hasShop ?? this.hasShop,
      error: error,
    );

  ShopState clearError() => ShopState(
      shop: shop,
      isLoading: isLoading,
      hasShop: hasShop,
    );
}

/// Shop state notifier
class ShopNotifier extends StateNotifier<ShopState> {

  ShopNotifier(this._shopService) : super(ShopState());
  final ShopService _shopService;

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
        );
      } else {
        state = ShopState(
          
        );
      }
    } catch (e) {
      state = ShopState(
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
    ShopType shopType = ShopType.general,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final shop = await _shopService.createShop(
        shopName: shopName,
        address: address,
        phone: phone,
        currency: currency,
        shopType: shopType,
      );

      state = ShopState(
        shop: shop,
        hasShop: true,
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
    ShopType? shopType,
  }) async {
    if (state.shop == null) {
      state = state.copyWith(error: 'No shop found');
      return false;
    }

    state = state.copyWith(isLoading: true);

    try {
      final updatedShop = await _shopService.updateShop(
        shopName: shopName,
        address: address,
        phone: phone,
        currency: currency,
        shopType: shopType,
      );

      state = ShopState(
        shop: updatedShop,
        hasShop: true,
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

    state = state.copyWith(isLoading: true);

    try {
      await _shopService.deleteShop();

      state = ShopState(
        
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
final shopServiceProvider = Provider<ShopService>((ref) => ShopService());

/// Shop state provider
final shopProvider = StateNotifierProvider<ShopNotifier, ShopState>((ref) {
  final shopService = ref.watch(shopServiceProvider);
  return ShopNotifier(shopService);
});

/// Current business type used to activate shop-specific UI and rules.
/// Missing shop data defaults to general for compatibility with existing
/// accounts and while the shop record is loading.
final shopTypeProvider = Provider<ShopType>((ref) => ref.watch(shopProvider).shop?.shopType ?? ShopType.general);
