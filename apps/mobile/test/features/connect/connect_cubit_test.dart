import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fluxora_core/entities/server_info.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';
import 'package:fluxora_mobile/features/connect/domain/repositories/server_discovery_repository.dart';
import 'package:fluxora_mobile/features/connect/presentation/cubit/connect_cubit.dart';
import 'package:fluxora_mobile/features/connect/presentation/cubit/connect_state.dart';

class _MockRepo extends Mock implements ServerDiscoveryRepository {}

void main() {
  late _MockRepo mockRepo;

  setUp(() => mockRepo = _MockRepo());

  const server = DiscoveredServer(
    name: 'Fluxora Server',
    ip: '192.168.1.10',
    port: 8000,
  );

  const serverInfo = ServerInfo(
    serverName: 'Fluxora Server',
    version: '0.1.0',
    tier: SubscriptionTier.free,
  );

  setUpAll(() {
    registerFallbackValue(serverInfo);
  });

  group('ConnectCubit', () {
    test('initial state is ConnectInitial', () {
      final cubit = ConnectCubit(repository: mockRepo);
      expect(cubit.state, isA<ConnectInitial>());
      cubit.close();
    });

    blocTest<ConnectCubit, ConnectState>(
      'emits [Searching, Found] when a server is discovered',
      build: () {
        when(() => mockRepo.discoverViaMulticast())
            .thenAnswer((_) => Stream.value(server));
        return ConnectCubit(repository: mockRepo);
      },
      act: (cubit) => cubit.startDiscovery(),
      expect: () => [isA<ConnectSearching>(), isA<ConnectFound>()],
    );

    blocTest<ConnectCubit, ConnectState>(
      'emits [Searching, Error] when discovery stream is empty',
      build: () {
        when(() => mockRepo.discoverViaMulticast())
            .thenAnswer((_) => const Stream.empty());
        return ConnectCubit(repository: mockRepo);
      },
      act: (cubit) => cubit.startDiscovery(),
      expect: () => [isA<ConnectSearching>(), isA<ConnectError>()],
    );

    blocTest<ConnectCubit, ConnectState>(
      'does not add duplicate servers with the same IP',
      build: () {
        when(() => mockRepo.discoverViaMulticast())
            .thenAnswer((_) => Stream.fromIterable([server, server]));
        return ConnectCubit(repository: mockRepo);
      },
      act: (cubit) => cubit.startDiscovery(),
      expect: () => [isA<ConnectSearching>(), isA<ConnectFound>()],
      verify: (cubit) {
        expect((cubit.state as ConnectFound).servers, hasLength(1));
      },
    );

    blocTest<ConnectCubit, ConnectState>(
      'accumulates multiple distinct servers',
      build: () {
        const second = DiscoveredServer(
          name: 'Second Server',
          ip: '192.168.1.11',
          port: 8000,
        );
        when(() => mockRepo.discoverViaMulticast())
            .thenAnswer((_) => Stream.fromIterable([server, second]));
        return ConnectCubit(repository: mockRepo);
      },
      act: (cubit) => cubit.startDiscovery(),
      expect: () => [
        isA<ConnectSearching>(),
        isA<ConnectFound>(),
        isA<ConnectFound>(),
      ],
      verify: (cubit) {
        expect((cubit.state as ConnectFound).servers, hasLength(2));
      },
    );
  });
}
