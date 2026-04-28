import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_state.dart';

class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit({required LibraryRepository repository})
      : _repository = repository,
        super(const LibraryInitial());

  final LibraryRepository _repository;
  static final _log = Logger();

  Future<void> load() async {
    emit(const LibraryLoading());
    try {
      final libraries = await _repository.getLibraries();
      final files = await _repository.getFiles();
      emit(LibraryLoaded(libraries: libraries, files: files));
    } on ApiException catch (e, st) {
      _log.e('Library load failed', error: e, stackTrace: st);
      emit(LibraryFailure(e.message));
    } catch (e, st) {
      _log.e('Library load failed', error: e, stackTrace: st);
      emit(const LibraryFailure('Unable to reach server. Is it running?'));
    }
  }

  void selectLibrary(String? libraryId) {
    final current = state;
    if (current is! LibraryLoaded) return;
    emit(LibraryLoaded(
      libraries: current.libraries,
      files: current.files,
      selectedLibraryId: libraryId,
    ));
  }
}
