/// Cubit backing the Home tab "Continue watching" rail.
///
/// Phase B backfill (`docs/10_planning/08_real_data_backfill_plan.md`
/// §3 row 1): replaces `MockData.continueWatching`.  Calls
/// `LibraryRepository.listContinueWatching(limit: 12)` once on first
/// build; pull-to-refresh on the parent `RefreshIndicator` triggers
/// `refresh()`.  Singleton-scoped in GetIt so re-entering the Home tab
/// doesn't drop the loaded list.
library;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';

sealed class ContinueWatchingState {
  const ContinueWatchingState();
}

class ContinueWatchingInitial extends ContinueWatchingState {
  const ContinueWatchingInitial();
}

class ContinueWatchingLoading extends ContinueWatchingState {
  const ContinueWatchingLoading();
}

class ContinueWatchingLoaded extends ContinueWatchingState {
  const ContinueWatchingLoaded(this.items);
  final List<MediaFile> items;
}

class ContinueWatchingFailure extends ContinueWatchingState {
  const ContinueWatchingFailure(this.message);
  final String message;
}

class ContinueWatchingCubit extends Cubit<ContinueWatchingState> {
  ContinueWatchingCubit({required LibraryRepository repository})
      : _repository = repository,
        super(const ContinueWatchingInitial());

  final LibraryRepository _repository;
  static final _log = Logger();

  Future<void> load({int limit = 12}) async {
    if (state is ContinueWatchingLoading) return;
    emit(const ContinueWatchingLoading());
    await _fetch(limit);
  }

  Future<void> refresh({int limit = 12}) => _fetch(limit);

  Future<void> _fetch(int limit) async {
    try {
      final items = await _repository.listContinueWatching(limit: limit);
      emit(ContinueWatchingLoaded(items));
    } on ApiException catch (e, st) {
      _log.e('Continue-watching load failed', error: e, stackTrace: st);
      emit(ContinueWatchingFailure(e.message));
    } catch (e, st) {
      _log.e('Continue-watching unexpected error', error: e, stackTrace: st);
      emit(const ContinueWatchingFailure(
        'Could not load continue-watching.',
      ));
    }
  }
}
