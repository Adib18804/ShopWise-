import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';

class CustomerState {

  const CustomerState({
    this.customers = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.successMessage,
  });
  final List<CustomerModel> customers;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;
  final String? successMessage;

  CustomerState copyWith({
    List<CustomerModel>? customers,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
    String? successMessage,
    bool clearMessages = false,
  }) =>
      CustomerState(
        customers: customers ?? this.customers,
        isLoading: isLoading ?? this.isLoading,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        error: clearMessages ? null : (error ?? this.error),
        successMessage:
            clearMessages ? null : (successMessage ?? this.successMessage),
      );
}

/// Manages the customer (Baki Khata) list with a real-time Firestore stream.
class CustomerNotifier extends StateNotifier<CustomerState> {
  CustomerNotifier(this._repo) : super(const CustomerState());

  final CustomerRepository _repo;
  StreamSubscription<List<CustomerModel>>? _sub;

  /// Subscribes to the real-time customers stream. Idempotent.
  void init() {
    if (_sub != null) return;
    state = state.copyWith(isLoading: true);
    _sub = _repo.customersStream().listen(
      (customers) {
        state = CustomerState(customers: customers);
      },
      onError: (Object error) {
        state = CustomerState(
          customers: state.customers,
          error: error is ApiException
              ? error.message
              : 'গ্রাহক তালিকা লোড করা যায়নি',
        );
      },
    );
  }

  Future<void> refresh() async {
    await _sub?.cancel();
    _sub = null;
    init();
  }

  // ---------------------------------------------------------------------------
  // CRUD
  // ---------------------------------------------------------------------------

  Future<CustomerModel?> createCustomer({
    required String name,
    required String phone,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final customer = await _repo.create(name: name, phone: phone);
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'গ্রাহক তৈরি হয়েছে',
      );
      return customer;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: error is ApiException ? error.message : 'গ্রাহক তৈরি করা যায়নি',
      );
      return null;
    }
  }

  Future<bool> updateCustomer(
    String docId, {
    String? name,
    String? phone,
  }) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _repo.update(docId, name: name, phone: phone);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: error is ApiException ? error.message : 'গ্রাহক আপডেট করা যায়নি',
      );
      return false;
    }
  }

  Future<bool> deleteCustomer(String docId) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _repo.delete(docId);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error: error is ApiException ? error.message : 'গ্রাহক মুছতে সমস্যা হয়েছে',
      );
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Baki management
  // ---------------------------------------------------------------------------

  /// Records a payment from the customer. Returns the updated model on success.
  Future<CustomerModel?> recordPayment(String docId, double amount) async {
    state = state.copyWith(isSubmitting: true);
    try {
      final updated = await _repo.recordPayment(docId, amount);
      state = state.copyWith(
        isSubmitting: false,
        successMessage: 'পেমেন্ট সফলভাবে রেকর্ড হয়েছে',
      );
      return updated;
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        error:
            error is ApiException ? error.message : 'পেমেন্ট রেকর্ড করা যায়নি',
      );
      return null;
    }
  }

  void clearMessages() => state = state.copyWith(clearMessages: true);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(),
);

final customerProvider =
    StateNotifierProvider<CustomerNotifier, CustomerState>((ref) => CustomerNotifier(ref.watch(customerRepositoryProvider)));
