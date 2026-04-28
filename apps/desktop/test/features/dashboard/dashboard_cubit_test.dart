import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/server_info.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_desktop/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/cubit/dashboard_state.dart';

class _MockDashboardRepo extends Mock implements DashboardRepository {}

void main() {
  late _MockDashboardRepo mockRepo;

  const serverInfo = ServerInfo(
    serverName: 'Test Server',
    version: '1.0.0',
    tier: SubscriptionTier.free,
  );

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

  setUp(() => mockRepo = _MockDashboardRepo());

  DashboardCubit buildCubit() => DashboardCubit(repository: mockRepo);

  group('DashboardCubit', () {
    test('initial state is DashboardInitial', () {
      final cubit = buildCubit();
      expect(cubit.state, isA<DashboardInitial>());
      cubit.close();
    });

    blocTest<DashboardCubit, DashboardState>(
      'emits [Loading, Loaded] when load succeeds',
      build: () {
        when(() => mockRepo.getServerInfo()).thenAnswer((_) async => serverInfo);
        when(() => mockRepo.getClients())
            .thenAnswer((_) async => [approvedClient, pendingClient]);
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [isA<DashboardLoading>(), isA<DashboardLoaded>()],
    );

    blocTest<DashboardCubit, DashboardState>(
      'loaded state carries correct server info and client lists',
      build: () {
        when(() => mockRepo.getServerInfo()).thenAnswer((_) async => serverInfo);
        when(() => mockRepo.getClients())
            .thenAnswer((_) async => [approvedClient, pendingClient]);
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardLoaded>()
            .having((s) => s.serverInfo.serverName, 'serverName', 'Test Server')
            .having((s) => s.approvedCount, 'approvedCount', 1)
            .having((s) => s.pendingCount, 'pendingCount', 1),
      ],
    );

    blocTest<DashboardCubit, DashboardState>(
      'emits [Loading, Failure] when getServerInfo throws ApiException',
      build: () {
        when(() => mockRepo.getServerInfo()).thenThrow(
          const ApiException(message: 'Server error', statusCode: 500),
        );
        when(() => mockRepo.getClients()).thenAnswer((_) async => []);
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardFailure>()
            .having((s) => s.message, 'message', 'Server error'),
      ],
    );

    blocTest<DashboardCubit, DashboardState>(
      'emits [Loading, Failure] with default message on generic exception',
      build: () {
        when(() => mockRepo.getServerInfo()).thenThrow(Exception('network'));
        when(() => mockRepo.getClients()).thenAnswer((_) async => []);
        return buildCubit();
      },
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<DashboardLoading>(),
        isA<DashboardFailure>().having(
          (s) => s.message,
          'message',
          'Unable to reach server. Is it running?',
        ),
      ],
    );

    test('DashboardLoaded approvedCount ignores non-approved clients', () {
      final state = DashboardLoaded(
        serverInfo: serverInfo,
        clients: [approvedClient, pendingClient],
      );
      expect(state.approvedCount, 1);
      expect(state.pendingCount, 1);
    });
  });
}
