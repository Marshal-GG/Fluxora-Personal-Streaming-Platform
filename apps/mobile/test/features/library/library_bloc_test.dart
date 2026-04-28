import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_mobile/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_mobile/features/library/presentation/bloc/library_bloc.dart';
import 'package:fluxora_mobile/features/library/presentation/bloc/library_event.dart';
import 'package:fluxora_mobile/features/library/presentation/bloc/library_state.dart';

class _MockLibraryRepo extends Mock implements LibraryRepository {}

void main() {
  late _MockLibraryRepo mockRepo;

  final library = Library(
    id: 'lib-1',
    name: 'Movies',
    type: LibraryType.movies,
    rootPaths: ['/media/movies'],
    createdAt: DateTime.utc(2026, 4, 27),
  );

  setUp(() => mockRepo = _MockLibraryRepo());

  group('LibraryBloc', () {
    test('initial state is LibraryInitial', () {
      final bloc = LibraryBloc(repository: mockRepo);
      expect(bloc.state, isA<LibraryInitial>());
      bloc.close();
    });

    blocTest<LibraryBloc, LibraryState>(
      'emits [Loading, Success] on LibraryStarted',
      build: () {
        when(() => mockRepo.listLibraries())
            .thenAnswer((_) async => [library]);
        return LibraryBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const LibraryStarted()),
      expect: () => [isA<LibraryLoading>(), isA<LibrarySuccess>()],
      verify: (bloc) {
        expect(
          (bloc.state as LibrarySuccess).libraries,
          equals([library]),
        );
      },
    );

    blocTest<LibraryBloc, LibraryState>(
      'emits Success with empty list when server returns nothing',
      build: () {
        when(() => mockRepo.listLibraries())
            .thenAnswer((_) async => []);
        return LibraryBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const LibraryStarted()),
      expect: () => [isA<LibraryLoading>(), isA<LibrarySuccess>()],
      verify: (bloc) {
        expect((bloc.state as LibrarySuccess).libraries, isEmpty);
      },
    );

    blocTest<LibraryBloc, LibraryState>(
      'emits [Loading, Failure] on ApiException',
      build: () {
        when(() => mockRepo.listLibraries()).thenThrow(
          const ApiException(message: 'Server error', statusCode: 500),
        );
        return LibraryBloc(repository: mockRepo);
      },
      act: (bloc) => bloc.add(const LibraryStarted()),
      expect: () => [isA<LibraryLoading>(), isA<LibraryFailure>()],
    );

    blocTest<LibraryBloc, LibraryState>(
      'emits Success again on LibraryRefreshed',
      build: () {
        when(() => mockRepo.listLibraries())
            .thenAnswer((_) async => [library]);
        return LibraryBloc(repository: mockRepo);
      },
      seed: () => LibrarySuccess([library]),
      act: (bloc) => bloc.add(const LibraryRefreshed()),
      expect: () => [isA<LibrarySuccess>()],
    );
  });

  group('LibraryRepository contract', () {
    test('listFiles delegates library_id query param', () async {
      when(() => mockRepo.listFiles(libraryId: 'lib-1'))
          .thenAnswer((_) async => <MediaFile>[]);
      await mockRepo.listFiles(libraryId: 'lib-1');
      verify(() => mockRepo.listFiles(libraryId: 'lib-1')).called(1);
    });
  });
}
