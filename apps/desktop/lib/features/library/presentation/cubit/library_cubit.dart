import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_core/entities/library.dart';
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

  /// Refresh quietly: re-fetches without flipping back to [LibraryLoading],
  /// so the UI doesn't flash a spinner after every mutation.
  Future<void> _refresh() async {
    try {
      final libraries = await _repository.getLibraries();
      final files = await _repository.getFiles();
      emit(LibraryLoaded(
        libraries: libraries,
        files: files,
        selectedLibraryId: state is LibraryLoaded
            ? (state as LibraryLoaded).selectedLibraryId
            : null,
      ));
    } on ApiException catch (e, st) {
      _log.e('Library refresh failed', error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _log.e('Library refresh failed', error: e, stackTrace: st);
      rethrow;
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

  Future<Library> createLibrary(
    String name,
    String type,
    List<String> rootPaths,
  ) async {
    try {
      final lib = await _repository.createLibrary(
        name: name,
        type: type,
        rootPaths: rootPaths,
      );
      await _refresh();
      return lib;
    } on ApiException catch (e, st) {
      _log.e('Create library failed', error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _log.e('Create library failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<Library> updateLibrary({
    required String libraryId,
    String? name,
    List<String>? rootPaths,
  }) async {
    try {
      final lib = await _repository.updateLibrary(
        libraryId: libraryId,
        name: name,
        rootPaths: rootPaths,
      );
      await _refresh();
      return lib;
    } on ApiException catch (e, st) {
      _log.e('Update library failed', error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _log.e('Update library failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteLibrary(String libraryId) async {
    try {
      await _repository.deleteLibrary(libraryId);
      final current = state;
      if (current is LibraryLoaded) {
        final remaining =
            current.libraries.where((l) => l.id != libraryId).toList();
        final remainingFiles =
            current.files.where((f) => f.libraryId != libraryId).toList();
        emit(LibraryLoaded(
          libraries: remaining,
          files: remainingFiles,
          selectedLibraryId: current.selectedLibraryId == libraryId
              ? null
              : current.selectedLibraryId,
        ));
      }
    } on ApiException catch (e, st) {
      _log.e('Delete library failed', error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _log.e('Delete library failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Returns the count of files added by the scan.
  Future<int> scanLibrary(String libraryId) async {
    try {
      final added = await _repository.scanLibrary(libraryId);
      await _refresh();
      return added;
    } on ApiException catch (e, st) {
      _log.e('Scan library failed', error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _log.e('Scan library failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Re-run TMDB enrichment for files in [libraryId] that lack a
  /// `tmdb_id`.  Returns `(matched, enriched, skippedDvr)` so the UI
  /// can render an exact toast.  Surfaces ApiException and other
  /// transport errors to the caller — the action button shows a
  /// SnackBar on failure rather than silently swallowing.
  Future<({int matched, int enriched, int skippedDvr})> enrichLibraryTmdb(
    String libraryId, {
    bool includeDvr = false,
  }) async {
    try {
      final result = await _repository.enrichLibraryTmdb(
        libraryId, includeDvr: includeDvr,
      );
      // Reload library + file list so any newly-set poster_url / title
      // shows up immediately in the list view.
      await _refresh();
      return result;
    } on ApiException catch (e, st) {
      _log.e('TMDB rescan failed', error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _log.e('TMDB rescan failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> uploadFile(String libraryId, String filePath) async {
    try {
      await _repository.uploadFileToLibrary(
          libraryId: libraryId, filePath: filePath);
      await _refresh();
    } on ApiException catch (e, st) {
      _log.e('Upload file failed', error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _log.e('Upload file failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  @override
  void emit(LibraryState state) {
    // Guard against late callbacks (in-flight HTTP requests) completing
    // after close() — common during hot-restart. See gotchas.md
    // "Cubit emit-after-close".
    if (isClosed) return;
    super.emit(state);
  }
}
