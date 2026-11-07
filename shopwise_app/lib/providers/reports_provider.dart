import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../models/daily_report_model.dart';
import '../repositories/reports_repository.dart';

class ReportsState {

  const ReportsState({this.isLoading = false, this.summary, this.error});
  final bool isLoading;
  final DailyReportModel? summary;
  final String? error;
}

class ReportsController extends StateNotifier<ReportsState> {

  ReportsController(this._repository) : super(const ReportsState());
  final ReportsRepository _repository;

  Future<void> load() async {
    state = ReportsState(isLoading: true, summary: state.summary);
    try {
      state = ReportsState(summary: await _repository.getDailySummary());
    } catch (error) {
      state = ReportsState(
        summary: state.summary,
        error: error is ApiException ? error.message : error.toString(),
      );
    }
  }
}

final reportsRepositoryProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(),
);

final reportsProvider = StateNotifierProvider<ReportsController, ReportsState>(
  (ref) => ReportsController(ref.watch(reportsRepositoryProvider)),
);
