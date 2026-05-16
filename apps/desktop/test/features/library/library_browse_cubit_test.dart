/// Tests for the Phase C additions on top of LibraryBrowseCubit:
///   - density toggle (compact / cosy / comfortable)
///   - multi-select state (toggle / extend / selectAllVisible / clear)
///   - shift-click anchor handling
///   - per-file index / thumbnail / scan-subtree action wrappers
///
/// Filter / sort / kind-filter coverage is exercised by Phase A/B tests
/// of `applyBrowseFilters` (pure function) — not duplicated here.
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fluxora_desktop/features/library/domain/entities/browse_entry.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_browse_cubit.dart';

class _MockRepo extends Mock implements LibraryRepository {}

BrowseEntry _entry(
  String name, {
  BrowseKind kind = BrowseKind.video,
  bool isDir = false,
  bool isIndexed = false,
  String? fileId,
}) {
  return BrowseEntry(
    name: name,
    kind: isDir ? BrowseKind.directory : kind,
    isDir: isDir,
    isHidden: false,
    sizeBytes: 1024,
    modifiedIso: '2026-05-16T10:00:00Z',
    mtimeUnix: 1715855400,
    isIndexed: isIndexed,
    fileId: fileId,
    media: null,
  );
}

BrowseResponse _response({
  required String libraryId,
  required String relativePath,
  required List<BrowseEntry> entries,
}) {
  return BrowseResponse(
    libraryId: libraryId,
    rootPath: r'D:\Library',
    relativePath: relativePath,
    parentPath: relativePath.isEmpty ? null : '',
    entries: entries,
  );
}

void main() {
  late _MockRepo repo;
  const libraryId = 'lib-1';

  setUp(() {
    repo = _MockRepo();
  });

  // ── Density ──────────────────────────────────────────────────────────────

  group('density', () {
    test('defaults to comfortable', () {
      final cubit = LibraryBrowseCubit(libraryId: libraryId, repository: repo);
      expect(cubit.density, BrowseDensity.comfortable);
    });

    test('setDensity advances the public getter only when changed',
        () async {
      when(() => repo.browseLibrary(
            libraryId: libraryId,
            path: '',
            showHidden: false,
          )).thenAnswer(
        (_) async => _response(
          libraryId: libraryId,
          relativePath: '',
          entries: [_entry('a.mp4')],
        ),
      );
      final cubit = LibraryBrowseCubit(libraryId: libraryId, repository: repo);
      await cubit.load();

      // Count Loaded emissions to ensure no-op calls don't re-emit.
      var loadedEmissions = 0;
      final sub = cubit.stream.listen((s) {
        if (s is LibraryBrowseLoaded) loadedEmissions++;
      });

      cubit.setDensity(BrowseDensity.compact);
      expect(cubit.density, BrowseDensity.compact);
      cubit.setDensity(BrowseDensity.compact); // identical — no emit
      cubit.setDensity(BrowseDensity.cosy);
      expect(cubit.density, BrowseDensity.cosy);

      await Future<void>.delayed(Duration.zero);
      expect(loadedEmissions, 2);
      await sub.cancel();
    });
  });

  // ── Multi-select ─────────────────────────────────────────────────────────

  group('multi-select', () {
    BrowseResponse listing(List<BrowseEntry> entries) =>
        _response(libraryId: libraryId, relativePath: '', entries: entries);

    Future<LibraryBrowseCubit> loaded(List<BrowseEntry> entries) async {
      when(() => repo.browseLibrary(
            libraryId: libraryId,
            path: '',
            showHidden: false,
          )).thenAnswer((_) async => listing(entries));
      final cubit = LibraryBrowseCubit(libraryId: libraryId, repository: repo);
      await cubit.load();
      return cubit;
    }

    test('toggleSelection toggles membership without clearing others',
        () async {
      final cubit = await loaded([
        _entry('a.mp4'),
        _entry('b.mp4'),
        _entry('c.mp4'),
      ]);
      cubit.selectOnly('a.mp4');
      cubit.toggleSelection('b.mp4');
      expect(cubit.selectedNames, {'a.mp4', 'b.mp4'});
      cubit.toggleSelection('a.mp4');
      expect(cubit.selectedNames, {'b.mp4'});
    });

    test('extendSelection selects the inclusive range from anchor', () async {
      final cubit = await loaded([
        _entry('a.mp4'),
        _entry('b.mp4'),
        _entry('c.mp4'),
        _entry('d.mp4'),
      ]);
      cubit.selectOnly('b.mp4');
      cubit.extendSelection('d.mp4');
      expect(cubit.selectedNames, {'b.mp4', 'c.mp4', 'd.mp4'});
    });

    test('extendSelection falls back to selectOnly without an anchor',
        () async {
      final cubit = await loaded([_entry('a.mp4'), _entry('b.mp4')]);
      // No prior selection => no anchor.
      cubit.extendSelection('b.mp4');
      expect(cubit.selectedNames, {'b.mp4'});
    });

    test('selectAllVisible selects every entry after filters apply',
        () async {
      final cubit = await loaded([
        _entry('a.mp4'),
        _entry('b.jpg', kind: BrowseKind.image),
        _entry('c.mp4'),
      ]);
      cubit.setKindFilter(BrowseKindFilter.videos);
      cubit.selectAllVisible();
      expect(cubit.selectedNames, {'a.mp4', 'c.mp4'});
    });

    test('clearSelection drops the anchor', () async {
      final cubit = await loaded([_entry('a.mp4'), _entry('b.mp4')]);
      cubit.selectOnly('a.mp4');
      cubit.extendSelection('b.mp4');
      cubit.clearSelection();
      // After clear, a fresh extendSelection should behave as selectOnly
      // (no anchor) — i.e. lay down a single-item selection.
      cubit.extendSelection('b.mp4');
      expect(cubit.selectedNames, {'b.mp4'});
    });

    test('hasMultiSelect reflects > 1 selected', () async {
      final cubit = await loaded([_entry('a.mp4'), _entry('b.mp4')]);
      cubit.selectOnly('a.mp4');
      expect(cubit.hasMultiSelect, isFalse);
      cubit.toggleSelection('b.mp4');
      expect(cubit.hasMultiSelect, isTrue);
    });
  });

  // ── Phase C action wrappers ──────────────────────────────────────────────

  group('action wrappers', () {
    setUp(() {
      // refresh() after each action calls repository.browseLibrary again.
      when(() => repo.browseLibrary(
            libraryId: libraryId,
            path: '',
            showHidden: false,
          )).thenAnswer(
        (_) async => _response(
          libraryId: libraryId,
          relativePath: '',
          entries: [_entry('a.mp4', isIndexed: true, fileId: 'file-a')],
        ),
      );
    });

    blocTest<LibraryBrowseCubit, LibraryBrowseState>(
      'indexEntry POSTs to repo and triggers refresh',
      build: () {
        when(() => repo.indexFile(
              libraryId: libraryId,
              relativePath: 'a.mp4',
            )).thenAnswer((_) async => const IndexFileResult(
              fileId: 'file-a',
              alreadyIndexed: false,
              enriched: false,
            ));
        return LibraryBrowseCubit(libraryId: libraryId, repository: repo);
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.indexEntry(_entry('a.mp4'));
      },
      verify: (_) {
        verify(() => repo.indexFile(
              libraryId: libraryId,
              relativePath: 'a.mp4',
            )).called(1);
        // 1× initial load + 1× refresh after the action
        verify(() => repo.browseLibrary(
              libraryId: libraryId,
              path: '',
              showHidden: false,
            )).called(2);
      },
    );

    blocTest<LibraryBrowseCubit, LibraryBrowseState>(
      'regenerateEntryThumbnail POSTs to repo and triggers refresh',
      build: () {
        when(() => repo.regenerateFileThumbnail('file-a'))
            .thenAnswer((_) async {});
        return LibraryBrowseCubit(libraryId: libraryId, repository: repo);
      },
      act: (cubit) async {
        await cubit.load();
        await cubit.regenerateEntryThumbnail(
          _entry('a.mp4', isIndexed: true, fileId: 'file-a'),
        );
      },
      verify: (_) {
        verify(() => repo.regenerateFileThumbnail('file-a')).called(1);
      },
    );

    blocTest<LibraryBrowseCubit, LibraryBrowseState>(
      'regenerateEntryThumbnail is a no-op when entry has no fileId',
      build: () => LibraryBrowseCubit(libraryId: libraryId, repository: repo),
      act: (cubit) async {
        await cubit.load();
        await cubit.regenerateEntryThumbnail(
          _entry('a.mp4', isIndexed: false),
        );
      },
      verify: (_) {
        verifyNever(() => repo.regenerateFileThumbnail(any()));
      },
    );

    blocTest<LibraryBrowseCubit, LibraryBrowseState>(
      'scanEntrySubtree POSTs and returns added count',
      build: () {
        when(() => repo.scanSubtree(
              libraryId: libraryId,
              relativePath: 'movies',
            )).thenAnswer((_) async => 3);
        return LibraryBrowseCubit(libraryId: libraryId, repository: repo);
      },
      act: (cubit) async {
        await cubit.load();
        final n = await cubit.scanEntrySubtree(
          _entry('movies', isDir: true),
        );
        expect(n, 3);
      },
      verify: (_) {
        verify(() => repo.scanSubtree(
              libraryId: libraryId,
              relativePath: 'movies',
            )).called(1);
      },
    );

    blocTest<LibraryBrowseCubit, LibraryBrowseState>(
      'scanEntrySubtree is a no-op on a file entry',
      build: () => LibraryBrowseCubit(libraryId: libraryId, repository: repo),
      act: (cubit) async {
        await cubit.load();
        final n = await cubit.scanEntrySubtree(_entry('a.mp4'));
        expect(n, 0);
      },
      verify: (_) {
        verifyNever(() => repo.scanSubtree(
              libraryId: any(named: 'libraryId'),
              relativePath: any(named: 'relativePath'),
            ));
      },
    );
  });

  // ── navigateToAbsolute (editable path textbox) ───────────────────────────

  group('navigateToAbsolute', () {
    setUp(() {
      when(() => repo.browseLibrary(
            libraryId: libraryId,
            path: '',
            showHidden: false,
          )).thenAnswer((_) async => _response(
            libraryId: libraryId,
            relativePath: '',
            entries: [_entry('a.mp4')],
          ));
      when(() => repo.browseLibrary(
            libraryId: libraryId,
            path: 'sub',
            showHidden: false,
          )).thenAnswer((_) async => _response(
            libraryId: libraryId,
            relativePath: 'sub',
            entries: [_entry('b.mp4')],
          ));
    });

    test('strips the matched root prefix + navigates', () async {
      final cubit = LibraryBrowseCubit(libraryId: libraryId, repository: repo);
      await cubit.load();
      final ok = await cubit.navigateToAbsolute(r'D:\Library\sub');
      expect(ok, isTrue);
      verify(() => repo.browseLibrary(
            libraryId: libraryId,
            path: 'sub',
            showHidden: false,
          )).called(1);
    });

    test('returns false when the input doesn\'t sit under the root',
        () async {
      final cubit = LibraryBrowseCubit(libraryId: libraryId, repository: repo);
      await cubit.load();
      final ok = await cubit.navigateToAbsolute(r'E:\OtherDrive');
      expect(ok, isFalse);
      // Only the initial load — no extra round-trip.
      verify(() => repo.browseLibrary(
            libraryId: libraryId,
            path: '',
            showHidden: false,
          )).called(1);
    });
  });
}
