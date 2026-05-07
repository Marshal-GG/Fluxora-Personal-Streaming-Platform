/// Unit tests for [MobileGroupsCubit] — load, refresh, action paths.
///
/// Covers M4 + M8 + M6 of `13_groups_v2_content_spaces.md`:
///   * load() hydrates state from /clients/me/visible-libraries
///   * enter() success refreshes + clears action-in-flight
///   * enter() 401 keeps state + sets lastError
///   * enroll() success refreshes
///   * lock() drops the grant + refreshes
///   * lockAll() walks unlocked groups sequentially
///   * MobileGroupRow.enrollmentState routing matches the server matrix
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fluxora_mobile/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_mobile/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:fluxora_mobile/features/groups/presentation/cubit/groups_state.dart';

class MockGroupsRepository extends Mock implements GroupsRepository {}

void main() {
  late MockGroupsRepository repository;

  const tEmpty = <String, dynamic>{
    'client_id': 'me',
    'library_ids': <String>[],
    'groups_contributing': <String, dynamic>{},
    'pin_locked_groups': <String>[],
    'enrollment_required_groups': <String>[],
    'time_locked_groups': <String>[],
    'groups': <Map<String, dynamic>>[],
  };

  Map<String, dynamic> tWithGroups({
    List<Map<String, dynamic>> groups = const [],
    Map<String, List<String>> contributing = const {},
    List<String> libraryIds = const [],
  }) {
    return {
      'client_id': 'me',
      'library_ids': libraryIds,
      'groups_contributing': contributing,
      'pin_locked_groups': <String>[],
      'enrollment_required_groups': <String>[],
      'time_locked_groups': <String>[],
      'groups': groups,
    };
  }

  Map<String, dynamic> sharedLockedGroup({
    String id = 'adults',
    String name = 'Adults',
  }) =>
      {
        'id': id,
        'name': name,
        'icon': 'lock',
        'color': '#A855F7',
        'is_public': false,
        'is_active': true,
        'requires_pin': true,
        'pin_model': 'shared',
        'pin_mode': 'session',
        'is_enrolled': false,
        'in_time_window': true,
        'is_unlocked': false,
        'grant_expires_at': null,
      };

  Map<String, dynamic> sharedUnlockedGroup({
    String id = 'adults',
    String name = 'Adults',
    String? expiresAt = '2026-05-08T10:00:00+00:00',
  }) =>
      {
        ...sharedLockedGroup(id: id, name: name),
        'is_unlocked': true,
        'grant_expires_at': expiresAt,
      };

  Map<String, dynamic> perClientNotEnrolledGroup({
    String id = 'family',
    String name = 'Family',
  }) =>
      {
        'id': id,
        'name': name,
        'icon': 'family',
        'color': '#10B981',
        'is_public': false,
        'is_active': true,
        'requires_pin': true,
        'pin_model': 'per-client',
        'pin_mode': 'session',
        'is_enrolled': false,
        'in_time_window': true,
        'is_unlocked': false,
        'grant_expires_at': null,
      };

  setUp(() {
    repository = MockGroupsRepository();
  });

  MobileGroupsCubit buildCubit() =>
      MobileGroupsCubit(repository: repository);

  group('MobileGroupsCubit.load', () {
    test('initial state is MobileGroupsInitial', () {
      expect(buildCubit().state, isA<MobileGroupsInitial>());
    });

    blocTest<MobileGroupsCubit, MobileGroupsState>(
      'emits Loading then Loaded with empty lists when nothing to surface',
      setUp: () {
        when(() => repository.myVisibleLibraries())
            .thenAnswer((_) async => tEmpty);
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<MobileGroupsLoading>(),
        isA<MobileGroupsLoaded>()
            .having((s) => s.groups, 'groups', isEmpty)
            .having((s) => s.libraryIds, 'libraryIds', isEmpty),
      ],
    );

    blocTest<MobileGroupsCubit, MobileGroupsState>(
      'inverts groups_contributing into per-library provenance map',
      setUp: () {
        when(() => repository.myVisibleLibraries()).thenAnswer(
          (_) async => tWithGroups(
            groups: [sharedUnlockedGroup()],
            // Server emits group_id → list[lib_id]; cubit inverts it
            // for the Visible Libraries card's "← granted by Adults"
            // captions.
            contributing: {'adults': ['lib-movies', 'lib-tv']},
            libraryIds: ['lib-movies', 'lib-tv'],
          ),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        final state = cubit.state as MobileGroupsLoaded;
        expect(
          state.groupsContributing,
          {
            'lib-movies': ['adults'],
            'lib-tv': ['adults'],
          },
        );
      },
    );

    blocTest<MobileGroupsCubit, MobileGroupsState>(
      'emits Failure on ApiException',
      setUp: () {
        when(() => repository.myVisibleLibraries()).thenThrow(
          const ApiException(message: 'No remote configured'),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<MobileGroupsLoading>(),
        isA<MobileGroupsFailure>().having(
          (s) => s.message,
          'message',
          'No remote configured',
        ),
      ],
    );
  });

  group('MobileGroupsCubit filtered views', () {
    test('lockedGroups + unlockedGroups split by is_unlocked', () {
      final state = MobileGroupsLoaded(
        groups: [
          MobileGroupRow.fromJson(sharedLockedGroup(id: 'a', name: 'A')),
          MobileGroupRow.fromJson(sharedUnlockedGroup(id: 'b', name: 'B')),
          MobileGroupRow.fromJson(
            perClientNotEnrolledGroup(id: 'c', name: 'C'),
          ),
        ],
        libraryIds: const [],
        groupsContributing: const {},
      );
      expect(state.lockedGroups.map((g) => g.id), ['a', 'c']);
      expect(state.unlockedGroups.map((g) => g.id), ['b']);
    });

    test(
        'enrollmentState picks per-client/not-enrolled → enrollmentRequired',
        () {
      final row =
          MobileGroupRow.fromJson(perClientNotEnrolledGroup());
      expect(row.enrollmentState, GroupEnrollmentState.enrollmentRequired);
    });

    test('enrollmentState picks per-client/enrolled → enrolled', () {
      final row = MobileGroupRow.fromJson({
        ...perClientNotEnrolledGroup(),
        'is_enrolled': true,
      });
      expect(row.enrollmentState, GroupEnrollmentState.enrolled);
    });

    test('enrollmentState picks shared → notRequired', () {
      final row = MobileGroupRow.fromJson(sharedLockedGroup());
      expect(row.enrollmentState, GroupEnrollmentState.notRequired);
    });

    test('enrollmentState picks non-gated → notRequired', () {
      final row = MobileGroupRow.fromJson({
        ...sharedLockedGroup(),
        'requires_pin': false,
      });
      expect(row.enrollmentState, GroupEnrollmentState.notRequired);
    });
  });

  group('MobileGroupsCubit.enter', () {
    blocTest<MobileGroupsCubit, MobileGroupsState>(
      'success path refreshes + clears actionInFlight',
      setUp: () {
        when(() => repository.myVisibleLibraries()).thenAnswer(
          (_) async => tWithGroups(groups: [sharedLockedGroup()]),
        );
        when(() => repository.enter('adults', '8472')).thenAnswer(
          (_) async => const GroupGrantIssued(
            expiresAt: '2026-05-08T10:00:00+00:00',
            pinMode: 'session',
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.enter('adults', '8472');
      },
      verify: (cubit) {
        final state = cubit.state as MobileGroupsLoaded;
        expect(state.actionInFlight, isNull);
        expect(state.lastError, isNull);
        verify(() => repository.enter('adults', '8472')).called(1);
        verify(() => repository.myVisibleLibraries()).called(2);
      },
    );

    blocTest<MobileGroupsCubit, MobileGroupsState>(
      '401 sets lastError, no refresh',
      setUp: () {
        when(() => repository.myVisibleLibraries()).thenAnswer(
          (_) async => tWithGroups(groups: [sharedLockedGroup()]),
        );
        when(() => repository.enter('adults', any())).thenThrow(
          const ApiException(
            message: 'Incorrect PIN (4 attempts remaining)',
            statusCode: 401,
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.enter('adults', '0000');
      },
      verify: (cubit) {
        final state = cubit.state as MobileGroupsLoaded;
        expect(state.lastError, contains('Incorrect PIN'));
        expect(state.actionInFlight, isNull);
        // Only the initial load fetched the visible-libraries; the
        // failed enter must NOT trigger a refresh.
        verify(() => repository.myVisibleLibraries()).called(1);
      },
    );
  });

  group('MobileGroupsCubit.enroll', () {
    blocTest<MobileGroupsCubit, MobileGroupsState>(
      'success path refreshes + grants the immediate session grant',
      setUp: () {
        when(() => repository.myVisibleLibraries()).thenAnswer(
          (_) async => tWithGroups(
            groups: [perClientNotEnrolledGroup()],
          ),
        );
        when(() => repository.enroll('family', '5283')).thenAnswer(
          (_) async => const GroupGrantIssued(
            expiresAt: '2026-05-08T10:00:00+00:00',
            pinMode: 'session',
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.enroll('family', '5283');
      },
      verify: (cubit) {
        final state = cubit.state as MobileGroupsLoaded;
        expect(state.actionInFlight, isNull);
        expect(state.lastError, isNull);
        verify(() => repository.enroll('family', '5283')).called(1);
      },
    );

    blocTest<MobileGroupsCubit, MobileGroupsState>(
      '409 already-enrolled surfaces server message',
      setUp: () {
        when(() => repository.myVisibleLibraries()).thenAnswer(
          (_) async => tWithGroups(
            groups: [perClientNotEnrolledGroup()],
          ),
        );
        when(() => repository.enroll(any(), any())).thenThrow(
          const ApiException(
            message: 'PIN already enrolled — use /enroll/change to replace it',
            statusCode: 409,
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.enroll('family', '5283');
      },
      verify: (cubit) {
        final state = cubit.state as MobileGroupsLoaded;
        expect(state.lastError, contains('already enrolled'));
      },
    );
  });

  group('MobileGroupsCubit.lock', () {
    blocTest<MobileGroupsCubit, MobileGroupsState>(
      'lock() drops grant + refreshes',
      setUp: () {
        when(() => repository.myVisibleLibraries()).thenAnswer(
          (_) async => tWithGroups(groups: [sharedUnlockedGroup()]),
        );
        when(() => repository.lock('adults')).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.lock('adults');
      },
      verify: (cubit) {
        verify(() => repository.lock('adults')).called(1);
        // Two fetches: initial load + post-lock refresh.
        verify(() => repository.myVisibleLibraries()).called(2);
      },
    );

    blocTest<MobileGroupsCubit, MobileGroupsState>(
      'lockAll() walks every unlocked group sequentially',
      setUp: () {
        when(() => repository.myVisibleLibraries()).thenAnswer(
          (_) async => tWithGroups(
            groups: [
              sharedUnlockedGroup(id: 'a', name: 'A'),
              sharedUnlockedGroup(id: 'b', name: 'B'),
              sharedLockedGroup(id: 'c', name: 'C'), // not unlocked
            ],
          ),
        );
        when(() => repository.lock(any())).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.lockAll();
      },
      verify: (_) {
        verify(() => repository.lock('a')).called(1);
        verify(() => repository.lock('b')).called(1);
        // 'c' was already locked — must not be re-locked.
        verifyNever(() => repository.lock('c'));
      },
    );

    blocTest<MobileGroupsCubit, MobileGroupsState>(
      'lockAll() continues past per-row failures',
      setUp: () {
        when(() => repository.myVisibleLibraries()).thenAnswer(
          (_) async => tWithGroups(
            groups: [
              sharedUnlockedGroup(id: 'a'),
              sharedUnlockedGroup(id: 'b'),
            ],
          ),
        );
        // First lock throws; cubit must continue + still call the
        // second.
        when(() => repository.lock('a')).thenThrow(
          const ApiException(message: 'down', statusCode: 500),
        );
        when(() => repository.lock('b')).thenAnswer((_) async {});
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.lockAll();
      },
      verify: (_) {
        verify(() => repository.lock('a')).called(1);
        verify(() => repository.lock('b')).called(1);
      },
    );
  });
}
