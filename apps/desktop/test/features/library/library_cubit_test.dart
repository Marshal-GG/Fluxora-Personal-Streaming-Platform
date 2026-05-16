import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_desktop/features/library/domain/entities/library.dart'
    as desktop;
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_cubit.dart';
import 'package:fluxora_desktop/features/library/presentation/cubit/library_state.dart';

class _MockRepo extends Mock implements LibraryRepository {}

void main() {
  late _MockRepo repo;

  final lib = Library(
    id: 'lib-1',
    name: 'Movies',
    type: LibraryType.movies,
    rootPaths: const ['D:/Movies'],
    fileCount: 3,
    totalSizeBytes: 30 * 1024 * 1024,
    lastScanned: DateTime.utc(2026, 5, 1),
    createdAt: DateTime.utc(2026, 5, 1),
    coverUrls: const [],
  );

  setUp(() {
    repo = _MockRepo();
    // Default stubs for the implicit `refresh()` call inside the cubit
    // helpers under test — keeps each test focused on one method.
    when(() => repo.getLibrariesWithOverrides()).thenAnswer(
      (_) async => (
        libraries: <Library>[],
        overrides: <String, desktop.LibraryCodecOverrides>{},
      ),
    );
    when(() => repo.getFiles()).thenAnswer((_) async => <MediaFile>[]);
  });

  group('regenerateThumbnails', () {
    blocTest<LibraryCubit, LibraryState>(
      'returns the queued count on success and refreshes',
      build: () {
        when(() => repo.regenerateThumbnails(lib.id))
            .thenAnswer((_) async => 5);
        return LibraryCubit(repository: repo);
      },
      act: (cubit) async {
        final n = await cubit.regenerateThumbnails(lib.id);
        expect(n, 5);
      },
      verify: (_) {
        verify(() => repo.regenerateThumbnails(lib.id)).called(1);
        // refresh() re-fetches libraries + files
        verify(() => repo.getLibrariesWithOverrides()).called(1);
        verify(() => repo.getFiles()).called(1);
      },
    );

    blocTest<LibraryCubit, LibraryState>(
      'rethrows on API failure without changing state',
      build: () {
        when(() => repo.regenerateThumbnails(lib.id))
            .thenThrow(Exception('500'));
        return LibraryCubit(repository: repo);
      },
      act: (cubit) async {
        await expectLater(
          () => cubit.regenerateThumbnails(lib.id),
          throwsA(isA<Exception>()),
        );
      },
      // refresh() must NOT fire on the error path
      verify: (_) {
        verifyNever(() => repo.getLibrariesWithOverrides());
        verifyNever(() => repo.getFiles());
      },
    );

    blocTest<LibraryCubit, LibraryState>(
      'returns zero when the server has no files to regenerate',
      build: () {
        when(() => repo.regenerateThumbnails(lib.id))
            .thenAnswer((_) async => 0);
        return LibraryCubit(repository: repo);
      },
      act: (cubit) async {
        final n = await cubit.regenerateThumbnails(lib.id);
        expect(n, 0);
      },
    );
  });

  // Sanity: LibrariesPayload still constructs correctly with our default
  // stub.  Catches a refactor that breaks the empty-state contract.
  test('default stub produces empty libraries + files', () async {
    final payload = await repo.getLibrariesWithOverrides();
    expect(payload.libraries, isEmpty);
    expect(payload.overrides, isEmpty);
    expect(await repo.getFiles(), isEmpty);
    // Silence the unused-fixture warning.
    expect(lib.id, 'lib-1');
    expect(desktop.LibraryCodecOverrides.empty.av1StreamCopyOverride, null);
  });
}
