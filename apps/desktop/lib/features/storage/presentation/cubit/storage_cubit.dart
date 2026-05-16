import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/library/data/services/library_events_service.dart';
import 'package:fluxora_desktop/features/storage/domain/repositories/storage_repository.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_state.dart';

class StorageCubit extends Cubit<StorageState> {
  StorageCubit({
    required StorageRepository repository,
    LibraryEventsService? events,
  })  : _repository = repository,
        super(const StorageInitial()) {
    // Real-time refresh on server-side `storage_changed` events.  Same
    // service as LibraryCubit listens on, different stream.
    _eventsSub = events?.storageChanged.listen((_) => refresh());
  }

  final StorageRepository _repository;
  static final _log = Logger();

  StreamSubscription<void>? _eventsSub;

  @override
  Future<void> close() {
    _eventsSub?.cancel();
    return super.close();
  }

  Future<void> load() async {
    emit(const StorageLoading());
    try {
      final breakdown = await _repository.fetch();
      emit(StorageLoaded(breakdown));
    } on ApiException catch (e, st) {
      _log.e('Storage load failed', error: e, stackTrace: st);
      emit(StorageFailure(e.message));
    } catch (e, st) {
      _log.e('Storage load failed', error: e, stackTrace: st);
      emit(const StorageFailure('Unable to load storage data.'));
    }
  }

  /// Silent re-fetch that doesn't flip the state back to
  /// [StorageLoading] — used on page re-mount to refresh cached data
  /// in the background without flashing a skeleton.  Failures are
  /// logged but swallowed (operator still sees the cached state).
  Future<void> refresh() async {
    try {
      final breakdown = await _repository.fetch();
      emit(StorageLoaded(breakdown));
    } catch (e, st) {
      _log.w('Storage refresh failed (keeping cached state)',
          error: e, stackTrace: st);
    }
  }

  @override
  void emit(StorageState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
