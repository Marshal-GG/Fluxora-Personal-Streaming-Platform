import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_mobile/features/library/presentation/bloc/library_event.dart';
import 'package:fluxora_mobile/features/library/presentation/bloc/library_state.dart';

class LibraryBloc extends Bloc<LibraryEvent, LibraryState> {
  LibraryBloc({required LibraryRepository repository})
      : _repository = repository,
        super(const LibraryInitial()) {
    on<LibraryStarted>(_onStarted);
    on<LibraryRefreshed>(_onRefreshed);
  }

  final LibraryRepository _repository;
  static final _log = Logger();

  Future<void> _onStarted(
    LibraryStarted event,
    Emitter<LibraryState> emit,
  ) async {
    emit(const LibraryLoading());
    await _fetchLibraries(emit);
  }

  Future<void> _onRefreshed(
    LibraryRefreshed event,
    Emitter<LibraryState> emit,
  ) async {
    await _fetchLibraries(emit);
  }

  Future<void> _fetchLibraries(Emitter<LibraryState> emit) async {
    try {
      final libraries = await _repository.listLibraries();
      emit(LibrarySuccess(libraries));
    } on ApiException catch (e, st) {
      _log.e('Failed to load libraries', error: e, stackTrace: st);
      emit(LibraryFailure(e.message));
    } catch (e, st) {
      _log.e('Unexpected error loading libraries', error: e, stackTrace: st);
      emit(const LibraryFailure('Failed to load libraries.'));
    }
  }
}
