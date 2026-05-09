import 'package:equatable/equatable.dart';
import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_candidate.dart';
import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_job.dart';

/// Sealed-union state for the Transcode page.  Three variants:
///
/// - [TranscodeInitial] — first load, nothing fetched yet.
/// - [TranscodeLoaded]  — at least one successful tick; `candidates`
///                       and `jobs` are the latest snapshots.
/// - [TranscodeFailure] — initial load failed with no prior data.
///                       Subsequent poll failures preserve the last
///                       loaded state instead of replacing it (same
///                       defensive pattern as the Clients cubit).
sealed class TranscodeState extends Equatable {
  const TranscodeState();

  @override
  List<Object?> get props => const [];
}

final class TranscodeInitial extends TranscodeState {
  const TranscodeInitial();
}

final class TranscodeLoaded extends TranscodeState {
  const TranscodeLoaded({
    required this.candidates,
    required this.jobs,
    this.selectedFileIds = const <String>{},
    this.lastFetchAt,
    this.busyJobIds = const <int>{},
    this.busyAction = false,
  });

  /// Most recent `/candidates` snapshot.
  final List<TranscodeCandidate> candidates;

  /// Most recent `/jobs` snapshot — every status the page cares about.
  final List<TranscodeJob> jobs;

  /// File ids currently checked in the Candidates tab.  Survives polls.
  final Set<String> selectedFileIds;

  /// When the last successful tick landed (UTC).  Null when only the
  /// initial fetch has been issued and not yet completed.
  final DateTime? lastFetchAt;

  /// Job ids with an in-flight cancel/retry — used to disable buttons
  /// while the request is round-tripping so the UI can't double-fire.
  final Set<int> busyJobIds;

  /// True while a `Start transcode` request is in flight.
  final bool busyAction;

  /// Jobs that are queued or actively running.
  Iterable<TranscodeJob> get activeJobs =>
      jobs.where((j) => j.status.isActive);

  /// Jobs that are done / failed / cancelled.
  Iterable<TranscodeJob> get terminalJobs =>
      jobs.where((j) => j.status.isTerminal);

  TranscodeLoaded copyWith({
    List<TranscodeCandidate>? candidates,
    List<TranscodeJob>? jobs,
    Set<String>? selectedFileIds,
    DateTime? lastFetchAt,
    Set<int>? busyJobIds,
    bool? busyAction,
  }) =>
      TranscodeLoaded(
        candidates: candidates ?? this.candidates,
        jobs: jobs ?? this.jobs,
        selectedFileIds: selectedFileIds ?? this.selectedFileIds,
        lastFetchAt: lastFetchAt ?? this.lastFetchAt,
        busyJobIds: busyJobIds ?? this.busyJobIds,
        busyAction: busyAction ?? this.busyAction,
      );

  @override
  List<Object?> get props => [
        candidates,
        jobs,
        selectedFileIds,
        lastFetchAt,
        busyJobIds,
        busyAction,
      ];
}

final class TranscodeFailure extends TranscodeState {
  const TranscodeFailure(this.message);
  final String message;

  @override
  List<Object?> get props => [message];
}
