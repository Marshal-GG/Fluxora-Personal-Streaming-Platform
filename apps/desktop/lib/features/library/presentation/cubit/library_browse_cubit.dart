import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_desktop/features/library/domain/entities/browse_entry.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';

/// Drives the folder-browser surface inside the library files screen.
///
/// One cubit per screen mount; holds the current library + path +
/// show-hidden toggle.  Navigation is via [navigateTo] (push into a
/// child directory) and [goUp] (resolve to `parent_path` from the
/// last server response).
class LibraryBrowseCubit extends Cubit<LibraryBrowseState> {
  LibraryBrowseCubit({
    required this.libraryId,
    required LibraryRepository repository,
  })  : _repository = repository,
        super(const LibraryBrowseInitial());

  final String libraryId;
  final LibraryRepository _repository;
  static final _log = Logger();

  /// Tracks the operator's hidden-files toggle.  Persisted in cubit
  /// state, not server-side — different libraries may have different
  /// hidden-content needs and the operator might toggle frequently.
  bool _showHidden = false;

  bool get showHidden => _showHidden;

  /// Initial load — fetches the library's root directory.
  Future<void> load() async {
    emit(const LibraryBrowseLoading(path: ''));
    await _fetch('');
  }

  /// Navigate into the given relative path (e.g. `sub/nested`).  Used
  /// for both folder clicks and breadcrumb segment clicks.
  Future<void> navigateTo(String relativePath) async {
    emit(LibraryBrowseLoading(path: relativePath));
    await _fetch(relativePath);
  }

  /// Walk one level up.  No-op at the root.
  Future<void> goUp() async {
    final current = state;
    final parent = current is LibraryBrowseLoaded
        ? current.response.parentPath
        : null;
    if (parent == null) return;
    await navigateTo(parent);
  }

  /// Flip the hidden-files toggle + re-fetch the current directory.
  Future<void> setShowHidden(bool value) async {
    if (_showHidden == value) return;
    _showHidden = value;
    final currentPath = _currentPath();
    emit(LibraryBrowseLoading(path: currentPath));
    await _fetch(currentPath);
  }

  String _currentPath() {
    final current = state;
    if (current is LibraryBrowseLoaded) return current.response.relativePath;
    if (current is LibraryBrowseLoading) return current.path;
    if (current is LibraryBrowseFailure) return current.path;
    return '';
  }

  Future<void> _fetch(String path) async {
    try {
      final response = await _repository.browseLibrary(
        libraryId: libraryId,
        path: path,
        showHidden: _showHidden,
      );
      emit(LibraryBrowseLoaded(response: response));
    } on ApiException catch (e, st) {
      _log.e('Browse failed', error: e, stackTrace: st);
      emit(LibraryBrowseFailure(path: path, message: e.message));
    } catch (e, st) {
      _log.e('Browse failed', error: e, stackTrace: st);
      emit(LibraryBrowseFailure(
        path: path,
        message: 'Unable to load directory: $e',
      ));
    }
  }

  @override
  void emit(LibraryBrowseState state) {
    if (isClosed) return;
    super.emit(state);
  }
}

sealed class LibraryBrowseState {
  const LibraryBrowseState();
}

class LibraryBrowseInitial extends LibraryBrowseState {
  const LibraryBrowseInitial();
}

class LibraryBrowseLoading extends LibraryBrowseState {
  const LibraryBrowseLoading({required this.path});

  /// Path being loaded — lets the breadcrumb stay stable while the
  /// listing is in flight (otherwise the operator would see the crumb
  /// vanish on every navigation).
  final String path;
}

class LibraryBrowseLoaded extends LibraryBrowseState {
  const LibraryBrowseLoaded({required this.response});

  final BrowseResponse response;
}

class LibraryBrowseFailure extends LibraryBrowseState {
  const LibraryBrowseFailure({required this.path, required this.message});

  final String path;
  final String message;
}
