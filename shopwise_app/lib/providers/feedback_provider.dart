import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/feedback_model.dart';
import '../repositories/feedback_repository.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (_) => FeedbackRepository(),
);

/// Force-refresh the token so a newly assigned/revoked custom claim is seen.
final isFirebaseAdminProvider = FutureProvider.autoDispose<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  final token = await user.getIdTokenResult(true);
  return token.claims?['admin'] == true;
});

final myFeedbackProvider =
    StreamProvider.autoDispose<List<FeedbackModel>>((ref) => ref.watch(feedbackRepositoryProvider).myFeedbackStream());

final allFeedbackProvider =
    StreamProvider.autoDispose<List<FeedbackModel>>((ref) => ref.watch(feedbackRepositoryProvider).allFeedbackStream());

final feedbackSubmitProvider = StateNotifierProvider.autoDispose<
    FeedbackSubmitController, AsyncValue<void>>((ref) => FeedbackSubmitController(ref.watch(feedbackRepositoryProvider)));

class FeedbackSubmitController extends StateNotifier<AsyncValue<void>> {
  FeedbackSubmitController(this._repository) : super(const AsyncData(null));

  final FeedbackRepository _repository;

  Future<void> submit({
    required String category,
    required String message,
  }) async {
    state = const AsyncLoading();
    try {
      await _repository.submit(category: category, message: message);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  void clearError() => state = const AsyncData(null);
}
