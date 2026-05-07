import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_desktop/features/clients/domain/repositories/clients_repository.dart';
import 'package:fluxora_desktop/features/clients/presentation/cubit/clients_cubit.dart';
import 'package:fluxora_desktop/features/clients/presentation/cubit/clients_state.dart';

class _MockClientsRepo extends Mock implements ClientsRepository {}

void main() {
  late _MockClientsRepo mockRepo;

  final approvedClient = ClientListItem(
    id: 'client-1',
    name: 'Pixel 8',
    platform: ClientPlatform.android,
    status: ClientStatus.approved,
    lastSeen: DateTime.utc(2026, 4, 28),
    isTrusted: true,
  );

  final pendingClient = ClientListItem(
    id: 'client-2',
    name: 'iPhone 15',
    platform: ClientPlatform.ios,
    status: ClientStatus.pending,
    lastSeen: DateTime.utc(2026, 4, 28),
    isTrusted: false,
  );

  setUp(() => mockRepo = _MockClientsRepo());

  ClientsCubit buildCubit() => ClientsCubit(repository: mockRepo);

  group('ClientsCubit.load', () {
    test('initial state is ClientsInitial', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<ClientsInitial>());
      cubit.close();
    });

    blocTest<ClientsCubit, ClientsState>(
      'emits [Loading, Loaded] when load succeeds',
      build: () {
        when(() => mockRepo.getClients())
            .thenAnswer((_) async => [approvedClient, pendingClient]);
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [isA<ClientsLoading>(), isA<ClientsLoaded>()],
    );

    blocTest<ClientsCubit, ClientsState>(
      'loaded state contains all clients and no filter',
      build: () {
        when(() => mockRepo.getClients())
            .thenAnswer((_) async => [approvedClient, pendingClient]);
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<ClientsLoading>(),
        isA<ClientsLoaded>()
            .having((s) => s.clients.length, 'total clients', 2)
            .having((s) => s.filtered.length, 'filtered (no filter)', 2)
            .having((s) => s.filter, 'filter', isNull),
      ],
    );

    blocTest<ClientsCubit, ClientsState>(
      'emits [Loading, Failure] when load throws ApiException',
      build: () {
        when(() => mockRepo.getClients()).thenThrow(
          const ApiException(message: 'Forbidden', statusCode: 403),
        );
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<ClientsLoading>(),
        isA<ClientsFailure>()
            .having((s) => s.message, 'message', 'Forbidden'),
      ],
    );

    blocTest<ClientsCubit, ClientsState>(
      'emits [Loading, Failure] with default message on generic exception',
      build: () {
        when(() => mockRepo.getClients()).thenThrow(Exception('timeout'));
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<ClientsLoading>(),
        isA<ClientsFailure>().having(
          (s) => s.message,
          'message',
          'Unable to reach server. Is it running?',
        ),
      ],
    );
  });

  group('ClientsCubit.setFilter', () {
    blocTest<ClientsCubit, ClientsState>(
      'filters to approved-only when filter is set to approved',
      build: () => buildCubit(),
      seed: () => ClientsLoaded(clients: [approvedClient, pendingClient]),
      act: (cubit) => cubit.setFilter(ClientStatus.approved),
      expect: () => [
        isA<ClientsLoaded>()
            .having((s) => s.filter, 'filter', ClientStatus.approved)
            .having((s) => s.filtered.length, 'filtered length', 1)
            .having((s) => s.filtered.first.id, 'filtered id', 'client-1'),
      ],
    );

    blocTest<ClientsCubit, ClientsState>(
      'clears filter when null is passed',
      build: () => buildCubit(),
      seed: () => ClientsLoaded(
        clients: [approvedClient, pendingClient],
        filter: ClientStatus.approved,
      ),
      act: (cubit) => cubit.setFilter(null),
      expect: () => [
        isA<ClientsLoaded>()
            .having((s) => s.filter, 'filter', isNull)
            .having((s) => s.filtered.length, 'all clients shown', 2),
      ],
    );

    blocTest<ClientsCubit, ClientsState>(
      'setFilter is a no-op when state is not ClientsLoaded',
      build: () => buildCubit(),
      act: (cubit) => cubit.setFilter(ClientStatus.approved),
      expect: () => [],
    );
  });

  group('ClientsCubit.approve', () {
    blocTest<ClientsCubit, ClientsState>(
      'adds client to processingIds then reloads after approval',
      build: () {
        when(() => mockRepo.approveClient('client-2')).thenAnswer((_) async {});
        when(() => mockRepo.getClients())
            .thenAnswer((_) async => [approvedClient, pendingClient]);
        return buildCubit();
      },
      seed: () => ClientsLoaded(clients: [approvedClient, pendingClient]),
      act: (cubit) => cubit.approve('client-2'),
      expect: () => [
        isA<ClientsLoaded>().having(
          (s) => s.processingIds,
          'processingIds during request',
          {'client-2'},
        ),
        // reload emits Loading then Loaded
        isA<ClientsLoading>(),
        isA<ClientsLoaded>(),
      ],
      verify: (_) {
        verify(() => mockRepo.approveClient('client-2')).called(1);
        verify(() => mockRepo.getClients()).called(1);
      },
    );

    blocTest<ClientsCubit, ClientsState>(
      'removes processingId when approve throws ApiException',
      build: () {
        when(() => mockRepo.approveClient(any())).thenThrow(
          const ApiException(message: 'Not found', statusCode: 404),
        );
        return buildCubit();
      },
      seed: () => ClientsLoaded(clients: [pendingClient]),
      act: (cubit) => cubit.approve('client-2'),
      expect: () => [
        isA<ClientsLoaded>().having(
          (s) => s.processingIds,
          'processingIds set during request',
          {'client-2'},
        ),
        isA<ClientsLoaded>().having(
          (s) => s.processingIds,
          'processingIds cleared after failure',
          isEmpty,
        ),
      ],
    );

    blocTest<ClientsCubit, ClientsState>(
      'approve is a no-op when state is not ClientsLoaded',
      build: () => buildCubit(),
      act: (cubit) => cubit.approve('client-2'),
      expect: () => [],
    );
  });

  group('ClientsCubit.reject', () {
    blocTest<ClientsCubit, ClientsState>(
      'adds client to processingIds then reloads after rejection',
      build: () {
        when(() => mockRepo.rejectClient('client-2')).thenAnswer((_) async {});
        when(() => mockRepo.getClients())
            .thenAnswer((_) async => [approvedClient]);
        return buildCubit();
      },
      seed: () => ClientsLoaded(clients: [approvedClient, pendingClient]),
      act: (cubit) => cubit.reject('client-2'),
      expect: () => [
        isA<ClientsLoaded>().having(
          (s) => s.processingIds,
          'processingIds during request',
          {'client-2'},
        ),
        isA<ClientsLoading>(),
        isA<ClientsLoaded>(),
      ],
      verify: (_) {
        verify(() => mockRepo.rejectClient('client-2')).called(1);
        verify(() => mockRepo.getClients()).called(1);
      },
    );

    blocTest<ClientsCubit, ClientsState>(
      'removes processingId when reject throws',
      build: () {
        when(() => mockRepo.rejectClient(any())).thenThrow(
          const ApiException(message: 'Server error', statusCode: 500),
        );
        return buildCubit();
      },
      seed: () => ClientsLoaded(clients: [pendingClient]),
      act: (cubit) => cubit.reject('client-2'),
      expect: () => [
        isA<ClientsLoaded>().having(
          (s) => s.processingIds,
          'processingIds set during request',
          {'client-2'},
        ),
        isA<ClientsLoaded>().having(
          (s) => s.processingIds,
          'processingIds cleared after failure',
          isEmpty,
        ),
      ],
    );

    blocTest<ClientsCubit, ClientsState>(
      'reject is a no-op when state is not ClientsLoaded',
      build: () => buildCubit(),
      act: (cubit) => cubit.reject('client-2'),
      expect: () => [],
    );
  });

  group('ClientsCubit.revoke', () {
    blocTest<ClientsCubit, ClientsState>(
      'adds client to processingIds then reloads after revoke',
      build: () {
        when(() => mockRepo.revokeClient('client-1')).thenAnswer((_) async {});
        when(() => mockRepo.getClients())
            .thenAnswer((_) async => [approvedClient, pendingClient]);
        return buildCubit();
      },
      seed: () => ClientsLoaded(clients: [approvedClient, pendingClient]),
      act: (cubit) => cubit.revoke('client-1'),
      expect: () => [
        isA<ClientsLoaded>().having(
          (s) => s.processingIds,
          'processingIds during request',
          {'client-1'},
        ),
        isA<ClientsLoading>(),
        isA<ClientsLoaded>(),
      ],
      verify: (_) {
        // Revoke must call DELETE /auth/revoke (revokeClient on the repo),
        // not POST /auth/reject — the two have different semantics.  The
        // test pins this contract so a future refactor can't silently
        // route revoke through rejectClient again.
        verify(() => mockRepo.revokeClient('client-1')).called(1);
        verifyNever(() => mockRepo.rejectClient(any()));
        verify(() => mockRepo.getClients()).called(1);
      },
    );

    blocTest<ClientsCubit, ClientsState>(
      'removes processingId when revoke throws',
      build: () {
        when(() => mockRepo.revokeClient(any())).thenThrow(
          const ApiException(message: 'Server error', statusCode: 500),
        );
        return buildCubit();
      },
      seed: () => ClientsLoaded(clients: [approvedClient]),
      act: (cubit) => cubit.revoke('client-1'),
      expect: () => [
        isA<ClientsLoaded>().having(
          (s) => s.processingIds,
          'processingIds set during request',
          {'client-1'},
        ),
        isA<ClientsLoaded>().having(
          (s) => s.processingIds,
          'processingIds cleared after failure',
          isEmpty,
        ),
      ],
    );

    blocTest<ClientsCubit, ClientsState>(
      'revoke is a no-op when state is not ClientsLoaded',
      build: () => buildCubit(),
      act: (cubit) => cubit.revoke('client-1'),
      expect: () => [],
    );
  });

  group('ClientsCubit.refreshSilent', () {
    final approvedClient2 = ClientListItem(
      id: 'client-3',
      name: 'iPad Pro',
      platform: ClientPlatform.ios,
      status: ClientStatus.approved,
      lastSeen: DateTime.utc(2026, 4, 28),
      isTrusted: true,
    );

    blocTest<ClientsCubit, ClientsState>(
      'replaces clients without flickering through ClientsLoading',
      build: () {
        when(() => mockRepo.getClients()).thenAnswer(
          (_) async => [approvedClient, approvedClient2],
        );
        return buildCubit();
      },
      seed: () => ClientsLoaded(clients: [approvedClient]),
      act: (cubit) => cubit.refreshSilent(),
      expect: () => [
        // Single emit — no ClientsLoading in between, that's the point.
        isA<ClientsLoaded>()
            .having((s) => s.clients.length, 'updated client count', 2),
      ],
    );

    blocTest<ClientsCubit, ClientsState>(
      'preserves filter across silent refresh',
      build: () {
        when(() => mockRepo.getClients())
            .thenAnswer((_) async => [approvedClient, pendingClient]);
        return buildCubit();
      },
      seed: () => ClientsLoaded(
        clients: [approvedClient],
        filter: ClientStatus.approved,
      ),
      act: (cubit) => cubit.refreshSilent(),
      expect: () => [
        isA<ClientsLoaded>()
            .having((s) => s.filter, 'filter retained', ClientStatus.approved)
            .having((s) => s.filtered.length, 'filtered count', 1),
      ],
    );

    blocTest<ClientsCubit, ClientsState>(
      'preserves processingIds so a revoke-in-flight stays disabled',
      build: () {
        when(() => mockRepo.getClients())
            .thenAnswer((_) async => [approvedClient]);
        return buildCubit();
      },
      seed: () => ClientsLoaded(
        clients: [approvedClient],
        processingIds: const {'client-1'},
      ),
      act: (cubit) => cubit.refreshSilent(),
      expect: () => [
        isA<ClientsLoaded>().having(
          (s) => s.processingIds,
          'in-flight ids preserved',
          {'client-1'},
        ),
      ],
    );

    blocTest<ClientsCubit, ClientsState>(
      'no-op when state is ClientsInitial',
      build: () => buildCubit(),
      act: (cubit) => cubit.refreshSilent(),
      expect: () => [],
      verify: (_) => verifyNever(() => mockRepo.getClients()),
    );

    blocTest<ClientsCubit, ClientsState>(
      'no-op when state is ClientsFailure',
      build: () => buildCubit(),
      seed: () => const ClientsFailure('whatever'),
      act: (cubit) => cubit.refreshSilent(),
      expect: () => [],
      verify: (_) => verifyNever(() => mockRepo.getClients()),
    );

    blocTest<ClientsCubit, ClientsState>(
      'swallows errors silently — never emits ClientsFailure on a poll tick',
      build: () {
        when(() => mockRepo.getClients()).thenThrow(
          const ApiException(message: 'transient blip', statusCode: 502),
        );
        return buildCubit();
      },
      seed: () => ClientsLoaded(clients: [approvedClient]),
      act: (cubit) => cubit.refreshSilent(),
      // Critical: a failed poll must NOT replace the last-known good state
      // with an error UI. The whole point of refreshSilent is "best-effort
      // background update" — if the network blips, the operator's view
      // stays stable instead of flickering to an error and back.
      expect: () => [],
    );
  });
}
