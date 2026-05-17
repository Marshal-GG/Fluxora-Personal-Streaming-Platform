import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_desktop/features/library/data/services/library_events_service.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_state.dart';

class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit({
    required LibraryRepository repository,
    LibraryEventsService? events,
  })  : _repository = repository,
        super(const LibraryInitial()) {
    // Subscribe to server-side `library_changed` events for real-time
    // refresh.  When the WS isn't wired (e.g. test harness) `events` is
    // null and the cubit falls back to manual Refresh-button-only.
    _eventsSub = events?.libraryChanged.listen((_) => refresh());
    // Per-library thumbnail-generation progress updates from the BG
    // worker — drives the chip on each library card.  Updates the
    // local map in place + re-emits LibraryLoaded so the UI repaints.
    _progressSub = events?.thumbnailsProgress.listen(_applyProgress);
  }

  final LibraryRepository _repository;
  static final _log = Logger();

  StreamSubscription<void>? _eventsSub;
  StreamSubscription<ThumbnailProgress>? _progressSub;

  @override
  Future<void> close() {
    _eventsSub?.cancel();
    _progressSub?.cancel();
    return super.close();
  }

  /// Merge a freshly-received [ThumbnailProgress] into the current
  /// LibraryLoaded state.  No-op when the cubit isn't in [LibraryLoaded].
  /// When `isComplete` is true (no pending+generating rows left for the
  /// library), the entry is removed from the map so the chip disappears
  /// on next paint.
  void _applyProgress(ThumbnailProgress progress) {
    final current = state;
    if (current is! LibraryLoaded) return;
    final next = Map<String, ThumbnailProgress>.from(current.thumbnailProgress);
    if (progress.isComplete) {
      next.remove(progress.libraryId);
    } else {
      next[progress.libraryId] = progress;
    }
    emit(LibraryLoaded(
      libraries: current.libraries,
      files: current.files,
      selectedLibraryId: current.selectedLibraryId,
      codecOverrides: current.codecOverrides,
      thumbnailProgress: next,
    ));
  }

  Future<void> load() async {
    emit(const LibraryLoading());
    try {
      final payload = await _repository.getLibrariesWithOverrides();
      final files = await _repository.getFiles();
      emit(LibraryLoaded(
        libraries: payload.libraries,
        files: files,
        codecOverrides: payload.overrides,
      ));
    } on ApiException catch (e, st) {
      _log.e('Library load failed', error: e, stackTrace: st);
      emit(LibraryFailure(e.message));
    } catch (e, st) {
      _log.e('Library load failed', error: e, stackTrace: st);
      emit(const LibraryFailure('Unable to reach server. Is it running?'));
    }
  }

  /// Refresh quietly: re-fetches without flipping back to [LibraryLoading],
  /// so the UI doesn't flash a spinner after every mutation.  Preserves
  /// the thumbnail-progress map across refreshes so the chip stays
  /// visible while cover_urls reload.
  Future<void> refresh() async {
    try {
      final payload = await _repository.getLibrariesWithOverrides();
      final files = await _repository.getFiles();
      final prev = state is LibraryLoaded ? state as LibraryLoaded : null;
      emit(LibraryLoaded(
        libraries: payload.libraries,
        files: files,
        codecOverrides: payload.overrides,
        selectedLibraryId: prev?.selectedLibraryId,
        thumbnailProgress: prev?.thumbnailProgress ?? const {},
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
      codecOverrides: current.codecOverrides,
      thumbnailProgress: current.thumbnailProgress,
    ));
  }

  Future<Library> createLibrary(
    String name,
    String type,
    List<String> rootPaths, {
    bool tmdbEnabled = true,
  }) async {
    try {
      final lib = await _repository.createLibrary(
        name: name,
        type: type,
        rootPaths: rootPaths,
        tmdbEnabled: tmdbEnabled,
      );
      await refresh();
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
    LibraryOverrideUpdate? av1Override,
    LibraryOverrideUpdate? vp9Override,
    bool? tmdbEnabled,
  }) async {
    try {
      final lib = await _repository.updateLibrary(
        libraryId: libraryId,
        name: name,
        rootPaths: rootPaths,
        av1Override: av1Override,
        vp9Override: vp9Override,
        tmdbEnabled: tmdbEnabled,
      );
      await refresh();
      return lib;
    } on ApiException catch (e, st) {
      _log.e('Update library failed', error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _log.e('Update library failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Plan 19 §M8 — `deleteSidecars: true` (default) sweeps any
  /// transcoded H.264 files attached to this library off disk; `false`
  /// keeps the on-disk files (useful when migrating to a new library
  /// definition without re-running the transcode worker).
  Future<void> deleteLibrary(
    String libraryId, {
    bool deleteSidecars = true,
  }) async {
    try {
      await _repository.deleteLibrary(
        libraryId,
        deleteSidecars: deleteSidecars,
      );
      final current = state;
      if (current is LibraryLoaded) {
        final remaining =
            current.libraries.where((l) => l.id != libraryId).toList();
        final remainingFiles =
            current.files.where((f) => f.libraryId != libraryId).toList();
        final remainingOverrides =
            Map.of(current.codecOverrides)..remove(libraryId);
        final remainingProgress =
            Map<String, ThumbnailProgress>.from(current.thumbnailProgress)
              ..remove(libraryId);
        emit(LibraryLoaded(
          libraries: remaining,
          files: remainingFiles,
          codecOverrides: remainingOverrides,
          selectedLibraryId: current.selectedLibraryId == libraryId
              ? null
              : current.selectedLibraryId,
          thumbnailProgress: remainingProgress,
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
      await refresh();
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
      await refresh();
      return result;
    } on ApiException catch (e, st) {
      _log.e('TMDB rescan failed', error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _log.e('TMDB rescan failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Queue every file in [libraryId] for thumbnail regeneration.  The
  /// server deletes the existing cached JPEGs and flips each row back
  /// to `pending` so the BG worker re-renders at current settings.
  /// Returns the count queued so the UI can render an exact toast.
  Future<int> regenerateThumbnails(String libraryId) async {
    try {
      final queued = await _repository.regenerateThumbnails(libraryId);
      // The `cover_urls` shape doesn't change immediately — thumbnails
      // are pending until the worker re-renders.  Refresh anyway so the
      // operator sees any side-effects (e.g. row counts changed) and
      // because the cards' cover_urls will start updating as the worker
      // produces new JPEGs.  No `Loading` flash via the cubit's silent
      // `refresh()` path.
      await refresh();
      return queued;
    } on ApiException catch (e, st) {
      _log.e('Regenerate thumbnails failed', error: e, stackTrace: st);
      rethrow;
    } catch (e, st) {
      _log.e('Regenerate thumbnails failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> uploadFile(String libraryId, String filePath) async {
    try {
      await _repository.uploadFileToLibrary(
          libraryId: libraryId, filePath: filePath);
      await refresh();
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
