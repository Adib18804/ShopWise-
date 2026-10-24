import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/sale_model.dart';
import '../models/sale_request.dart';
import '../repositories/sales_repository.dart';

class SalesState {
  final bool isLoading;
  final SaleModel? sale;
  final String? error;
  final String? successMessage;

  const SalesState({
    this.isLoading = false,
    this.sale,
    this.error,
    this.successMessage,
  });
}

class SalesController extends StateNotifier<SalesState> {
  final SalesRepository _repository;

  SalesController(this._repository) : super(const SalesState());

  Future<bool> processSale(SaleRequest request) async {
    state = const SalesState(isLoading: true);
    try {
      final sale = await _repository.processSale(request);
      state = SalesState(
        sale: sale,
        successMessage:
            '\u09ac\u09bf\u0995\u09cd\u09b0\u09df \u09b8\u09ab\u09b2\u09ad\u09be\u09ac\u09c7 \u09b8\u09ae\u09cd\u09aa\u09a8\u09cd\u09a8 \u09b9\u09df\u09c7\u099b\u09c7',
      );
      return true;
    } catch (error) {
      state = SalesState(
        error: error is ApiException ? error.message : error.toString(),
      );
      return false;
    }
  }

  void clearResult() => state = const SalesState();
}

final salesRepositoryProvider = Provider<SalesRepository>(
  (ref) => SalesRepository(),
);

final salesProvider = StateNotifierProvider<SalesController, SalesState>(
  (ref) => SalesController(ref.watch(salesRepositoryProvider)),
);
