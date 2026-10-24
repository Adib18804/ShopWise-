import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_exception.dart';
import '../models/batch_model.dart';
import '../services/batch_service.dart';

class BatchState {
  final List<BatchModel> batches;
  final double currentStock;
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? stockHistory;
  final Map<String, dynamic>? fefo;

  const BatchState({
    this.batches = const [],
    this.currentStock = 0,
    this.isLoading = false,
    this.error,
    this.stockHistory,
    this.fefo,
  });

  BatchState copyWith({
    List<BatchModel>? batches,
    double? currentStock,
    bool? isLoading,
    String? error,
    Map<String, dynamic>? stockHistory,
    Map<String, dynamic>? fefo,
  }) =>
      BatchState(
        batches: batches ?? this.batches,
        currentStock: currentStock ?? this.currentStock,
        isLoading: isLoading ?? this.isLoading,
        error: error,
        stockHistory: stockHistory ?? this.stockHistory,
        fefo: fefo ?? this.fefo,
      );
}

class BatchNotifier extends StateNotifier<BatchState> {
  final int productId;
  final BatchService _service;

  BatchNotifier(this.productId, this._service) : super(const BatchState());

  Future<void> load({bool includeDepleted = true}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.getBatches(productId, includeDepleted: includeDepleted);
      final product = result['product'] as Map<String, dynamic>;
      final batches = (result['batches'] as List)
          .map((item) => BatchModel.fromJson(item as Map<String, dynamic>))
          .toList();
      state = BatchState(
        batches: batches,
        currentStock: (product['current_stock'] as num).toDouble(),
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        error: error is ApiException ? error.message : 'স্টক তথ্য লোড করা যায়নি',
      );
    }
  }

  Future<bool> addBatch({
    required String? batchNumber,
    required DateTime purchaseDate,
    required DateTime? expiryDate,
    required double quantity,
    required double purchasePrice,
  }) async {
    try {
      await _service.addBatch(
        productId: productId,
        batchNumber: batchNumber,
        purchaseDate: purchaseDate,
        expiryDate: expiryDate,
        quantity: quantity,
        purchasePrice: purchasePrice,
      );
      await load();
      return true;
    } catch (error) {
      state = state.copyWith(error: error is ApiException ? error.message : 'স্টক যোগ করা যায়নি');
      return false;
    }
  }

  Future<bool> updateBatch(int batchId, Map<String, dynamic> changes) async {
    try {
      await _service.updateBatch(batchId, changes);
      await load();
      return true;
    } catch (error) {
      state = state.copyWith(error: error is ApiException ? error.message : 'ব্যাচ আপডেট করা যায়নি');
      return false;
    }
  }

  Future<bool> deactivateBatch(int batchId) async {
    try {
      await _service.deactivateBatch(batchId);
      await load();
      return true;
    } catch (error) {
      state = state.copyWith(error: error is ApiException ? error.message : 'ব্যাচ বন্ধ করা যায়নি');
      return false;
    }
  }

  Future<void> loadStockHistory() async {
    try {
      final history = await _service.getStockHistory(productId);
      state = state.copyWith(stockHistory: history, error: null);
    } catch (error) {
      state = state.copyWith(error: error is ApiException ? error.message : 'স্টক ইতিহাস লোড করা যায়নি');
    }
  }

  Future<void> loadFefo() async {
    try {
      final result = await _service.getFefoRecommendations(productId);
      state = state.copyWith(fefo: result, error: null);
    } catch (error) {
      state = state.copyWith(error: error is ApiException ? error.message : 'FEFO তথ্য লোড করা যায়নি');
    }
  }
}

final batchServiceProvider = Provider<BatchService>((ref) => BatchService());

final batchProvider = StateNotifierProvider.family<BatchNotifier, BatchState, int>((ref, productId) {
  return BatchNotifier(productId, ref.watch(batchServiceProvider));
});
