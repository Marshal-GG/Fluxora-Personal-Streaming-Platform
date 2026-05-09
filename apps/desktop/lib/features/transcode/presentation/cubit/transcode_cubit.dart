import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';

import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_candidate.dart';
import 'package:fluxora_desktop/features/transcode/domain/repositories/transcode_repository.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_state.dart';

/// Drives the three-tab Transcode page.
///
/// Polling cadence:
///  - `/jobs` every 2 s (live progress + status flips).
///  - `/storage` every 5 s (cheap aggregate query — spec calls out the
///    cadence explicitly so the strip doesn't churn the server's SUM
///    query 30× a minute).
///
/// Both polls run while the page is mounted and stop on close.  No
/// WebSocket — the desktop is consistent with the rest of the
/// live-data screens (SystemStats / TranscodingCubit / Clients).
class TranscodeCubit extends Cubit<TranscodeState> {
  TranscodeCubit({required TranscodeRepository repository})
      : _repository = repository,
        super(const TranscodeInitial());

  final TranscodeRepository _repository;
  static final _log = Logger();
  Timer? _jobsTimer;
  Timer? _storageTimer;

  static const Duration _jobsInterval = Duration(seconds: 2);
  static const Duration _storageInterval = Duration(seconds: 5);

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Fetch once immediately, then start polling.
  /// `/candidates` is fetched alongside the first load and on explicit
  /// `loadCandidates()` calls — it doesn't change second-to-second so
  /// hitting it on every poll would waste round trips.
  void start() {
    if (_jobsTimer != null) return;
    unawaited(loadCandidates());
    unawaited(_refreshStorage());
    _jobsTimer = Timer.periodic(_jobsInterval, (_) => _refreshJobs());
    _storageTimer = Timer.periodic(_storageInterval, (_) => _refreshStorage());
  }

  void stop() {
    _jobsTimer?.cancel();
    _jobsTimer = null;
    _storageTimer?.cancel();
    _storageTimer = null;
  }

  // ── Public commands ───────────────────────────────────────────────────────

  /// Initial load — fetches candidates and jobs together.  Emits
  /// [TranscodeLoaded] on success or [TranscodeFailure] on the first
  /// attempt; later poll-failures preserve the previous state.
  Future<void> loadCandidates() async {
    try {
      final candidates = await _repository.getCandidates();
      final jobs = await _repository.getJobs();
      if (isClosed) return;
      final prev = state;
      emit(
        TranscodeLoaded(
          candidates: candidates,
          jobs: jobs,
          selectedFileIds: prev is TranscodeLoaded
              // Drop ids that no longer appear in the candidate list
              // (their job has landed and the row is gone).
              ? prev.selectedFileIds
                  .where((id) => candidates.any((c) => c.fileId == id))
                  .toSet()
              : const <String>{},
          lastFetchAt: DateTime.now().toUtc(),
          busyJobIds: prev is TranscodeLoaded ? prev.busyJobIds : const {},
          busyAction: false,
          storage: prev is TranscodeLoaded ? prev.storage : null,
          expandedPaths: prev is TranscodeLoaded
              ? prev.expandedPaths
              : const <String>{},
          queuePreset: prev is TranscodeLoaded
              ? prev.queuePreset
              : TranscodePreset.recommended,
        ),
      );
    } catch (e, st) {
      _log.e('TranscodeCubit.loadCandidates failed',
          error: e, stackTrace: st);
      if (isClosed) return;
      if (state is TranscodeInitial) {
        emit(TranscodeFailure(e.toString()));
      }
    }
  }

  /// Toggle the selection set in the Candidates tab.  Ids that are not
  /// in the current candidate list are silently dropped — the cubit
  /// never holds stale ids past a reload.
  void selectFiles(Set<String> ids) {
    final s = state;
    if (s is! TranscodeLoaded) return;
    final knownIds = s.candidates.map((c) => c.fileId).toSet();
    final clean = ids.intersection(knownIds);
    emit(s.copyWith(selectedFileIds: clean));
  }

  /// Convenience — flip a single candidate's checkbox.
  void toggleSelection(String fileId) {
    final s = state;
    if (s is! TranscodeLoaded) return;
    final next = Set<String>.from(s.selectedFileIds);
    if (!next.add(fileId)) next.remove(fileId);
    selectFiles(next);
  }

  /// Bulk-select / bulk-deselect every leaf under a folder node.
  /// `leafFileIds` is the recursive flatten of the node's candidates —
  /// callers (the folder-tree widget) compute it from `_FolderNode.flatten`.
  ///
  /// When [select] is true the leaves are added to the current selection
  /// (preserving any other selected files); when false they are removed.
  void selectFolder(Iterable<String> leafFileIds, bool select) {
    final s = state;
    if (s is! TranscodeLoaded) return;
    final next = Set<String>.from(s.selectedFileIds);
    if (select) {
      next.addAll(leafFileIds);
    } else {
      next.removeAll(leafFileIds);
    }
    selectFiles(next);
  }

  /// Select every candidate currently visible.
  void selectAll() {
    final s = state;
    if (s is! TranscodeLoaded) return;
    selectFiles(s.candidates.map((c) => c.fileId).toSet());
  }

  /// Clear the selection set.
  void clearSelection() {
    final s = state;
    if (s is! TranscodeLoaded) return;
    selectFiles(const <String>{});
  }

  /// Toggle a folder-tree node's expanded state.
  void toggleExpanded(String absolutePath) {
    final s = state;
    if (s is! TranscodeLoaded) return;
    final next = Set<String>.from(s.expandedPaths);
    if (!next.add(absolutePath)) next.remove(absolutePath);
    emit(s.copyWith(expandedPaths: next));
  }

  /// Set the default expand-state of every node up-front (Candidates +
  /// History tabs both call this on first render to expand the top
  /// level by default).
  void seedExpanded(Iterable<String> paths) {
    final s = state;
    if (s is! TranscodeLoaded) return;
    if (s.expandedPaths.isNotEmpty) return;
    emit(s.copyWith(expandedPaths: paths.toSet()));
  }

  /// Pick a quality preset for the Queue dialog.
  void setQueuePreset(TranscodePreset preset) {
    final s = state;
    if (s is! TranscodeLoaded) return;
    if (s.queuePreset == preset) return;
    emit(s.copyWith(queuePreset: preset));
  }

  /// POST /queue with the current selection and preset, then refresh
  /// jobs so the Queue tab shows the freshly enqueued rows immediately
  /// instead of waiting up to 2 s for the next poll.
  Future<void> startTranscode() async {
    final s = state;
    if (s is! TranscodeLoaded) return;
    if (s.selectedFileIds.isEmpty || s.busyAction) return;
    emit(s.copyWith(busyAction: true));
    try {
      await _repository.queueJobs(
        fileIds: s.selectedFileIds.toList(),
        preset: s.queuePreset,
      );
      await _refreshAll();
    } catch (e, st) {
      _log.e('TranscodeCubit.startTranscode failed',
          error: e, stackTrace: st);
      if (isClosed) return;
      final cur = state;
      if (cur is TranscodeLoaded) {
        emit(cur.copyWith(busyAction: false));
      }
    }
  }

  /// DELETE /jobs/{id} then refresh.  Marks the row busy so the Cancel
  /// button on that single row stays disabled mid-request.
  Future<void> cancelJob(int jobId) async {
    final s = state;
    if (s is! TranscodeLoaded) return;
    if (s.busyJobIds.contains(jobId)) return;
    emit(s.copyWith(busyJobIds: {...s.busyJobIds, jobId}));
    try {
      await _repository.cancelJob(jobId);
      await _refreshJobs(force: true);
    } catch (e, st) {
      _log.e('TranscodeCubit.cancelJob($jobId) failed',
          error: e, stackTrace: st);
    } finally {
      final cur = state;
      if (!isClosed && cur is TranscodeLoaded) {
        emit(cur.copyWith(
          busyJobIds: cur.busyJobIds.where((i) => i != jobId).toSet(),
        ));
      }
    }
  }

  /// Bulk cancel — issues one DELETE per job sequentially so a flaky
  /// network can't leave half the queue in an indeterminate state.
  Future<void> cancelJobs(Iterable<int> jobIds) async {
    for (final id in jobIds) {
      await cancelJob(id);
    }
  }

  /// POST /jobs/{id}/retry and then refresh.  The new job id is logged
  /// but not surfaced — it appears in the Queue tab on the next poll.
  Future<void> retryJob(int jobId) async {
    final s = state;
    if (s is! TranscodeLoaded) return;
    if (s.busyJobIds.contains(jobId)) return;
    emit(s.copyWith(busyJobIds: {...s.busyJobIds, jobId}));
    try {
      final newId = await _repository.retryJob(jobId);
      _log.i('Transcode job $jobId retried as $newId');
      await _refreshJobs(force: true);
    } catch (e, st) {
      _log.e('TranscodeCubit.retryJob($jobId) failed',
          error: e, stackTrace: st);
    } finally {
      final cur = state;
      if (!isClosed && cur is TranscodeLoaded) {
        emit(cur.copyWith(
          busyJobIds: cur.busyJobIds.where((i) => i != jobId).toSet(),
        ));
      }
    }
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  /// Background tick — `/jobs` only.  Failures are swallowed so a
  /// transient blip doesn't blank out the operator's view.  Pass
  /// `force: true` after a mutation to skip the initial-state guard.
  Future<void> _refreshJobs({bool force = false}) async {
    if (isClosed) return;
    final s = state;
    if (s is! TranscodeLoaded && !force) return;
    try {
      final jobs = await _repository.getJobs();
      if (isClosed) return;
      final cur = state;
      if (cur is TranscodeLoaded) {
        emit(cur.copyWith(jobs: jobs, lastFetchAt: DateTime.now().toUtc()));
      } else if (force) {
        // Mutation completed before the first /candidates load returned —
        // emit a minimal Loaded so the Queue tab can render the fresh row.
        emit(TranscodeLoaded(
          candidates: const <TranscodeCandidate>[],
          jobs: jobs,
          lastFetchAt: DateTime.now().toUtc(),
        ));
      }
    } catch (e, st) {
      _log.w('TranscodeCubit._refreshJobs failed (non-fatal)',
          error: e, stackTrace: st);
    }
  }

  /// Background tick — `/storage`.  Same swallow-and-log pattern as
  /// `_refreshJobs`; a single failed fetch keeps the previous snapshot
  /// rather than blanking the strip.
  Future<void> _refreshStorage() async {
    if (isClosed) return;
    try {
      final storage = await _repository.getStorage();
      if (isClosed) return;
      final cur = state;
      if (cur is TranscodeLoaded) {
        emit(cur.copyWith(storage: storage));
      }
    } catch (e, st) {
      _log.w('TranscodeCubit._refreshStorage failed (non-fatal)',
          error: e, stackTrace: st);
    }
  }

  /// Refresh both endpoints — used after `startTranscode` because the
  /// candidate list shrinks once the selected files have jobs.  Server
  /// excludes files with `transcoded_path IS NOT NULL`, but a queued
  /// job alone doesn't change that.  We still re-fetch candidates so
  /// the operator sees the new job rows + a stable list.
  Future<void> _refreshAll() async {
    if (isClosed) return;
    try {
      final candidates = await _repository.getCandidates();
      final jobs = await _repository.getJobs();
      if (isClosed) return;
      final cur = state;
      if (cur is TranscodeLoaded) {
        emit(cur.copyWith(
          candidates: candidates,
          jobs: jobs,
          // Drop ids that have left the candidate list (server-side
          // dedupe / completion).  selectFiles() can't run here because
          // we want the emit to bundle candidates + jobs in a single
          // state change; building the set inline matches that intent.
          selectedFileIds: cur.selectedFileIds
              .where((id) => candidates.any((c) => c.fileId == id))
              .toSet(),
          lastFetchAt: DateTime.now().toUtc(),
          busyAction: false,
        ));
      }
    } catch (e, st) {
      _log.w('TranscodeCubit._refreshAll failed (non-fatal)',
          error: e, stackTrace: st);
      final cur = state;
      if (!isClosed && cur is TranscodeLoaded) {
        emit(cur.copyWith(busyAction: false));
      }
    }
  }

  @override
  Future<void> close() {
    stop();
    return super.close();
  }
}
