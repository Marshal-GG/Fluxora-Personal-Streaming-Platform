import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/recent_activity/domain/repositories/recent_activity_repository.dart';
import 'package:fluxora_desktop/features/recent_activity/presentation/cubit/recent_activity_state.dart';

class RecentActivityCubit extends Cubit<RecentActivityState> {
  RecentActivityCubit({required RecentActivityRepository repository})
      : _repository = repository,
        super(const RecentActivityInitial());

  final RecentActivityRepository _repository;
  static final _log = Logger();

  Future<void> load() async {
    emit(const RecentActivityLoading());
    try {
      final events = await _repository.fetch(limit: 4);
      emit(RecentActivityLoaded(events));
    } on ApiException catch (e, st) {
      _log.e('RecentActivity load failed', error: e, stackTrace: st);
      emit(RecentActivityFailure(e.message));
    } catch (e, st) {
      _log.e('RecentActivity load failed', error: e, stackTrace: st);
      emit(const RecentActivityFailure('Unable to load recent activity.'));
    }
  }

  Future<void> refresh() => load();
}
