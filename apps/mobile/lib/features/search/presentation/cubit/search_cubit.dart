/// Cubit backing the Search tab.
///
/// Phase B backfill (`docs/10_planning/08_real_data_backfill_plan.md`
/// §3 row 2): replaces the in-memory `MockData` filter with
/// `LibraryRepository.searchFiles(q, limit)`.  Server uses SQL `LIKE`
/// for v1 (FTS5 is the v2 swap-in).  This cubit debounces user input
/// 300 ms before firing a request so each keystroke doesn't slam the
/// server.
library;

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';

sealed class SearchState {
  const SearchState();
}

/// Empty query — render the recent-searches / trending-search chrome.
class SearchIdle extends SearchState {
  const SearchIdle();
}

class SearchLoading extends SearchState {
  const SearchLoading();
}

class SearchLoaded extends SearchState {
  const SearchLoaded({required this.query, required this.results});
  final String query;
  final List<MediaFile> results;
}

class SearchFailure extends SearchState {
  const SearchFailure(this.message);
  final String message;
}

class SearchCubit extends Cubit<SearchState> {
  SearchCubit({
    required LibraryRepository repository,
    Duration debounce = const Duration(milliseconds: 300),
  })  : _repository = repository,
        _debounce = debounce,
        super(const SearchIdle());

  final LibraryRepository _repository;
  final Duration _debounce;
  static final _log = Logger();

  Timer? _debounceTimer;
  int _requestSeq = 0;

  /// Called from the screen's `onChanged`.  Debounces by [debounce]
  /// and ignores stale responses if the user keeps typing.
  void queryChanged(String query) {
    _debounceTimer?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      emit(const SearchIdle());
      return;
    }
    _debounceTimer = Timer(_debounce, () => _fetch(trimmed));
  }

  Future<void> _fetch(String query) async {
    final seq = ++_requestSeq;
    emit(const SearchLoading());
    try {
      final results = await _repository.searchFiles(query: query, limit: 30);
      // If a newer query has fired since we started, drop our result.
      if (seq != _requestSeq) return;
      emit(SearchLoaded(query: query, results: results));
    } on ApiException catch (e, st) {
      _log.e('Search failed for "$query"', error: e, stackTrace: st);
      if (seq != _requestSeq) return;
      emit(SearchFailure(e.message));
    } catch (e, st) {
      _log.e('Search unexpected error', error: e, stackTrace: st);
      if (seq != _requestSeq) return;
      emit(const SearchFailure('Could not run that search.'));
    }
  }

  @override
  Future<void> close() {
    _debounceTimer?.cancel();
    return super.close();
  }
}
