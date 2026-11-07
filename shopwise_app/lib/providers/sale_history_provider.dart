import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shopwise_app/features/sales/screens/create_sale_screen.dart' show CreateSaleScreen;

import '../core/network/api_exception.dart';
import '../models/sale_model.dart';
import '../repositories/invoice_repository.dart';

class SaleHistoryState {

  const SaleHistoryState({
    this.invoices = const [],
    this.isLoading = false,
    this.error,
  });
  final List<SaleModel> invoices;
  final bool isLoading;
  final String? error;

  SaleHistoryState copyWith({
    List<SaleModel>? invoices,
    bool? isLoading,
    String? error,
  }) =>
      SaleHistoryState(
        invoices: invoices ?? this.invoices,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// Provides a real-time list of all invoices for the Sale History screen.
///
/// Subscribes to [InvoiceRepository.invoicesStream] once; the stream delivers
/// updates whenever an invoice is created (e.g. after a sale in
/// [CreateSaleScreen]), so the history list stays live without polling.
class SaleHistoryNotifier extends StateNotifier<SaleHistoryState> {
  SaleHistoryNotifier(this._repo) : super(const SaleHistoryState());

  final InvoiceRepository _repo;
  StreamSubscription<List<SaleModel>>? _sub;

  /// Subscribes to the real-time invoices stream. Safe to call multiple times
  /// (subsequent calls are no-ops while the subscription is active).
  void init() {
    if (_sub != null) return;
    state = state.copyWith(isLoading: true);
    _sub = _repo.invoicesStream().listen(
      (invoices) {
        state = SaleHistoryState(invoices: invoices);
      },
      onError: (Object error) {
        state = SaleHistoryState(
          invoices: state.invoices,
          error: error is ApiException
              ? error.message
              : 'বিক্রয় ইতিহাস লোড করা যায়নি',
        );
      },
    );
  }

  /// Force-refresh: cancel the existing subscription and re-subscribe.
  Future<void> refresh() async {
    await _sub?.cancel();
    _sub = null;
    init();
  }

  void clearError() => state = state.copyWith();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final invoiceRepositoryProvider = Provider<InvoiceRepository>(
  (ref) => InvoiceRepository(),
);

final saleHistoryProvider =
    StateNotifierProvider<SaleHistoryNotifier, SaleHistoryState>((ref) => SaleHistoryNotifier(ref.watch(invoiceRepositoryProvider)));
