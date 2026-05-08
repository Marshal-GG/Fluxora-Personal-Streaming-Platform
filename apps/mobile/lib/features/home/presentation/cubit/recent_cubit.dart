/// Cubit backing the Home tab "Recently added" rail.
///
/// Phase A backfill (`docs/10_planning/08_real_data_backfill_plan.md`
/// §9.2): replaces `MockData.recentlyAdded`.  Calls
/// `LibraryRepository.listRecentFiles(limit: 12)` once on first build —
/// the rail does not auto-refresh; pull-to-refresh on the parent
/// `RefreshIndicator` triggers `refresh()`.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';

sealed class RecentState {
  const RecentState();
}

class RecentInitial extends RecentState {
  const RecentInitial();
}

class RecentLoading extends RecentState {
  const RecentLoading();
}

class RecentLoaded extends RecentState {
  const RecentLoaded(this.items);
  final List<MediaFile> items;
}

class RecentFailure extends RecentState {
  const RecentFailure(this.message);
  final String message;
}

class RecentCubit extends Cubit<RecentState> {
  RecentCubit({required LibraryRepository repository})
      : _repository = repository,
        super(const RecentInitial());

  final LibraryRepository _repository;
  static final _log = Logger();

  Future<void> load({int limit = 12}) async {
    if (state is RecentLoading) return;
    emit(const RecentLoading());
    await _fetch(limit);
  }

  Future<void> refresh({int limit = 12}) => _fetch(limit);

  Future<void> _fetch(int limit) async {
    try {
      final items = await _repository.listRecentFiles(limit: limit);
      emit(RecentLoaded(items));
    } on ApiException catch (e, st) {
      _log.e('Recent rail load failed', error: e, stackTrace: st);
      emit(RecentFailure(e.message));
    } catch (e, st) {
      _log.e('Recent rail unexpected error', error: e, stackTrace: st);
      emit(const RecentFailure('Could not load recent additions.'));
    }
  }

  @override
  void emit(RecentState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
