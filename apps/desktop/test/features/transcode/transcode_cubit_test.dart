import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_candidate.dart';
import 'package:fluxora_desktop/features/transcode/domain/entities/transcode_job.dart';
import 'package:fluxora_desktop/features/transcode/domain/repositories/transcode_repository.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_cubit.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_state.dart';

class _MockRepo extends Mock implements TranscodeRepository {}

void main() {
  late _MockRepo repo;

  // ── Fixtures ─────────────────────────────────────────────────────────────
  const candidateAv1 = TranscodeCandidate(
    fileId: 'file-1',
    name: 'Avicii - The Nights.mkv',
    libraryId: 'lib-1',
    sizeBytes: 60 * 1024 * 1024,
    videoCodec: 'av1',
    durationSec: 190,
    estOutputSizeBytes: 120 * 1024 * 1024,
  );

  const candidateVp9 = TranscodeCandidate(
    fileId: 'file-2',
    name: 'Old Movie.webm',
    libraryId: 'lib-1',
    sizeBytes: 800 * 1024 * 1024,
    videoCodec: 'vp9',
    durationSec: 5400,
    estOutputSizeBytes: 1200 * 1024 * 1024,
  );

  const runningJob = TranscodeJob(
    id: 11,
    fileId: 'file-1',
    fileName: 'Avicii - The Nights.mkv',
    status: TranscodeJobStatus.running,
    progressPct: 31.0,
    etaSec: 60,
    error: null,
    outputPath: null,
    encoder: 'h264_nvenc',
    createdAt: 1700000000,
    startedAt: 1700000010,
    finishedAt: null,
  );

  const failedJob = TranscodeJob(
    id: 22,
    fileId: 'file-2',
    fileName: 'Old Movie.webm',
    status: TranscodeJobStatus.failed,
    progressPct: 0.0,
    etaSec: null,
    error: 'disk_full: out of space on D:\\',
    outputPath: null,
    encoder: 'h264_nvenc',
    createdAt: 1700000100,
    startedAt: 1700000110,
    finishedAt: 1700000180,
  );

  setUp(() {
    repo = _MockRepo();
  });

  TranscodeCubit buildCubit() => TranscodeCubit(repository: repo);

  // Default-stub helper — every test calls loadCandidates() at some point.
  void stubInitial({
    List<TranscodeCandidate>? candidates,
    List<TranscodeJob>? jobs,
  }) {
    when(() => repo.getCandidates())
        .thenAnswer((_) async => candidates ?? [candidateAv1, candidateVp9]);
    when(() => repo.getJobs())
        .thenAnswer((_) async => jobs ?? <TranscodeJob>[]);
  }

  group('TranscodeCubit.loadCandidates', () {
    test('initial state is TranscodeInitial', () {
      stubInitial();
      final cubit = buildCubit();
      expect(cubit.state, isA<TranscodeInitial>());
      cubit.close();
    });

    blocTest<TranscodeCubit, TranscodeState>(
      'emits [Loaded] when both fetches succeed',
      build: () {
        stubInitial();
        return buildCubit();
      },
      act: (cubit) => cubit.loadCandidates(),
      expect: () => [
        isA<TranscodeLoaded>()
            .having((s) => s.candidates.length, 'candidates length', 2)
            .having((s) => s.jobs, 'jobs', isEmpty)
            .having((s) => s.selectedFileIds, 'no selection', isEmpty),
      ],
    );

    blocTest<TranscodeCubit, TranscodeState>(
      'emits [Failure] when initial getCandidates throws',
      build: () {
        when(() => repo.getCandidates()).thenThrow(Exception('boom'));
        return buildCubit();
      },
      act: (cubit) => cubit.loadCandidates(),
      expect: () => [isA<TranscodeFailure>()],
    );

    blocTest<TranscodeCubit, TranscodeState>(
      'preserves last good state on a subsequent failed reload',
      build: () {
        // First call succeeds, second call throws — covers the
        // "transient blip on re-fetch" case.
        var calls = 0;
        when(() => repo.getCandidates()).thenAnswer((_) async {
          calls++;
          if (calls == 1) return [candidateAv1];
          throw Exception('transient');
        });
        when(() => repo.getJobs()).thenAnswer((_) async => <TranscodeJob>[]);
        return buildCubit();
      },
      act: (cubit) async {
        await cubit.loadCandidates();
        await cubit.loadCandidates();
      },
      // Two emissions: the first (success), then nothing on the failed
      // refresh because the cubit deliberately skips the emit when it
      // already has a Loaded state.  No Failure leak.
      expect: () => [isA<TranscodeLoaded>()],
    );
  });

  group('TranscodeCubit.selectFiles / toggleSelection', () {
    blocTest<TranscodeCubit, TranscodeState>(
      'updates the selected set when given known ids',
      build: () => buildCubit(),
      seed: () => const TranscodeLoaded(
        candidates: [candidateAv1, candidateVp9],
        jobs: <TranscodeJob>[],
      ),
      act: (cubit) => cubit.selectFiles({'file-1', 'file-2'}),
      expect: () => [
        isA<TranscodeLoaded>().having(
          (s) => s.selectedFileIds,
          'selectedFileIds',
          {'file-1', 'file-2'},
        ),
      ],
    );

    blocTest<TranscodeCubit, TranscodeState>(
      'silently drops unknown ids',
      build: () => buildCubit(),
      seed: () => const TranscodeLoaded(
        candidates: [candidateAv1],
        jobs: <TranscodeJob>[],
      ),
      act: (cubit) => cubit.selectFiles({'file-1', 'ghost-id'}),
      expect: () => [
        isA<TranscodeLoaded>().having(
          (s) => s.selectedFileIds,
          'unknown id stripped',
          {'file-1'},
        ),
      ],
    );

    blocTest<TranscodeCubit, TranscodeState>(
      'toggleSelection adds-then-removes a single id',
      build: () => buildCubit(),
      seed: () => const TranscodeLoaded(
        candidates: [candidateAv1],
        jobs: <TranscodeJob>[],
      ),
      act: (cubit) async {
        cubit.toggleSelection('file-1');
        cubit.toggleSelection('file-1');
      },
      expect: () => [
        isA<TranscodeLoaded>()
            .having((s) => s.selectedFileIds, 'added', {'file-1'}),
        isA<TranscodeLoaded>()
            .having((s) => s.selectedFileIds, 'removed', isEmpty),
      ],
    );

    blocTest<TranscodeCubit, TranscodeState>(
      'is a no-op before the first load (state is TranscodeInitial)',
      build: () => buildCubit(),
      act: (cubit) => cubit.selectFiles({'file-1'}),
      expect: () => <TranscodeState>[],
    );
  });

  group('TranscodeCubit.startTranscode', () {
    blocTest<TranscodeCubit, TranscodeState>(
      'POSTs /queue with the selected ids then refreshes both endpoints',
      build: () {
        when(() => repo.queueJobs(fileIds: ['file-1']))
            .thenAnswer((_) async => [99]);
        when(() => repo.getCandidates())
            .thenAnswer((_) async => <TranscodeCandidate>[]);
        when(() => repo.getJobs()).thenAnswer((_) async => [runningJob]);
        return buildCubit();
      },
      seed: () => const TranscodeLoaded(
        candidates: [candidateAv1, candidateVp9],
        jobs: <TranscodeJob>[],
        selectedFileIds: {'file-1'},
      ),
      act: (cubit) => cubit.startTranscode(),
      expect: () => [
        // Busy flag flips on
        isA<TranscodeLoaded>().having((s) => s.busyAction, 'busy', true),
        // Refresh: candidate list now empty, jobs now has the new row,
        // busy flag flips off
        isA<TranscodeLoaded>()
            .having((s) => s.candidates, 'candidates refreshed', isEmpty)
            .having((s) => s.jobs.length, 'jobs refreshed', 1)
            .having((s) => s.busyAction, 'busy cleared', false)
            // Selection set drops file-1 because it left the candidate
            // list — operator shouldn't see a phantom checkbox state.
            .having((s) => s.selectedFileIds, 'stale selection cleared',
                isEmpty),
      ],
      verify: (_) {
        verify(() => repo.queueJobs(fileIds: ['file-1'])).called(1);
        // Refresh = both endpoints, exactly once each.
        verify(() => repo.getCandidates()).called(1);
        verify(() => repo.getJobs()).called(1);
      },
    );

    blocTest<TranscodeCubit, TranscodeState>(
      'is a no-op when nothing is selected',
      build: () => buildCubit(),
      seed: () => const TranscodeLoaded(
        candidates: [candidateAv1],
        jobs: <TranscodeJob>[],
      ),
      act: (cubit) => cubit.startTranscode(),
      expect: () => <TranscodeState>[],
      verify: (_) => verifyNever(
        () => repo.queueJobs(fileIds: any(named: 'fileIds')),
      ),
    );

    blocTest<TranscodeCubit, TranscodeState>(
      'clears busy flag when /queue throws',
      build: () {
        when(() => repo.queueJobs(fileIds: any(named: 'fileIds')))
            .thenThrow(Exception('500 server error'));
        return buildCubit();
      },
      seed: () => const TranscodeLoaded(
        candidates: [candidateAv1],
        jobs: <TranscodeJob>[],
        selectedFileIds: {'file-1'},
      ),
      act: (cubit) => cubit.startTranscode(),
      expect: () => [
        isA<TranscodeLoaded>().having((s) => s.busyAction, 'busy on', true),
        isA<TranscodeLoaded>()
            .having((s) => s.busyAction, 'busy cleared on error', false),
      ],
      verify: (_) {
        verifyNever(() => repo.getCandidates());
        verifyNever(() => repo.getJobs());
      },
    );
  });

  group('TranscodeCubit.cancelJob', () {
    blocTest<TranscodeCubit, TranscodeState>(
      'DELETEs /jobs/{id} then refreshes /jobs',
      build: () {
        when(() => repo.cancelJob(11)).thenAnswer((_) async {});
        when(() => repo.getJobs()).thenAnswer((_) async => <TranscodeJob>[]);
        return buildCubit();
      },
      seed: () => const TranscodeLoaded(
        candidates: [candidateAv1],
        jobs: [runningJob],
      ),
      act: (cubit) => cubit.cancelJob(11),
      expect: () => [
        // Mark busy
        isA<TranscodeLoaded>().having(
          (s) => s.busyJobIds,
          'busy set',
          {11},
        ),
        // Refresh after DELETE — empty jobs list now.
        isA<TranscodeLoaded>()
            .having((s) => s.jobs, 'jobs refreshed', isEmpty),
        // Clear busy
        isA<TranscodeLoaded>().having(
          (s) => s.busyJobIds,
          'busy cleared',
          isEmpty,
        ),
      ],
      verify: (_) {
        verify(() => repo.cancelJob(11)).called(1);
        verify(() => repo.getJobs()).called(1);
      },
    );

    blocTest<TranscodeCubit, TranscodeState>(
      'is a no-op when called before initial load',
      build: () => buildCubit(),
      act: (cubit) => cubit.cancelJob(11),
      expect: () => <TranscodeState>[],
      verify: (_) => verifyNever(() => repo.cancelJob(any())),
    );
  });

  group('TranscodeCubit.retryJob', () {
    blocTest<TranscodeCubit, TranscodeState>(
      'POSTs /jobs/{id}/retry then refreshes /jobs',
      build: () {
        when(() => repo.retryJob(22)).thenAnswer((_) async => 222);
        when(() => repo.getJobs()).thenAnswer((_) async => [failedJob]);
        return buildCubit();
      },
      seed: () => const TranscodeLoaded(
        candidates: [candidateVp9],
        jobs: [failedJob],
      ),
      act: (cubit) => cubit.retryJob(22),
      expect: () => [
        isA<TranscodeLoaded>().having((s) => s.busyJobIds, 'busy set', {22}),
        // Server returned the original failed row; refresh emits it
        // verbatim — the cubit doesn't try to filter.
        isA<TranscodeLoaded>()
            .having((s) => s.jobs.length, 'jobs refreshed', 1),
        isA<TranscodeLoaded>().having(
          (s) => s.busyJobIds,
          'busy cleared',
          isEmpty,
        ),
      ],
      verify: (_) {
        verify(() => repo.retryJob(22)).called(1);
        verify(() => repo.getJobs()).called(1);
      },
    );
  });
}
