// Update goldens with: flutter test --update-goldens test/goldens/m3_dashboard_golden_test.dart
//
// Golden tests are tagged 'golden' so CI can opt-out:
//   flutter test --exclude-tags=golden
//
// See test/goldens/_README.md for platform-rendering notes.

@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:mocktail/mocktail.dart';

import 'package:fluxora_core/entities/activity_event.dart';
import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/library_storage_breakdown.dart';
import 'package:fluxora_core/entities/server_info.dart';
import 'package:fluxora_core/entities/system_stats.dart';

import 'package:fluxora_desktop/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:fluxora_desktop/features/recent_activity/domain/repositories/recent_activity_repository.dart';
import 'package:fluxora_desktop/features/recent_activity/presentation/cubit/recent_activity_cubit.dart';
import 'package:fluxora_desktop/features/recent_activity/presentation/cubit/recent_activity_state.dart';
import 'package:fluxora_desktop/features/storage/domain/repositories/storage_repository.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_cubit.dart';
import 'package:fluxora_desktop/features/storage/presentation/cubit/storage_state.dart';
import 'package:fluxora_desktop/features/system_stats/presentation/cubit/system_stats_cubit.dart';
import 'package:fluxora_desktop/features/system_stats/domain/repositories/system_stats_repository.dart';
import 'package:fluxora_desktop/features/dashboard/presentation/screens/dashboard_screen.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class _MockDashboardRepo extends Mock implements DashboardRepository {}
class _MockStorageRepo extends Mock implements StorageRepository {}
class _MockActivityRepo extends Mock implements RecentActivityRepository {}
class _MockSystemStatsRepo extends Mock implements SystemStatsRepository {}

// ── Deterministic test data ───────────────────────────────────────────────────

const _serverInfo = ServerInfo(
  serverName: 'Fluxora Home',
  version: '1.5.0',
  tier: SubscriptionTier.pro,
  remoteUrl: 'https://home.example.com',
);

final _clients = List.generate(
  6,
  (i) => ClientListItem(
    id: 'client-$i',
    name: 'Device ${i + 1}',
    platform: i.isEven ? ClientPlatform.android : ClientPlatform.ios,
    status: ClientStatus.approved,
    lastSeen: DateTime.utc(2026, 5, 2, 10, i),
    isTrusted: true,
  ),
);

const _storage = LibraryStorageBreakdown(
  totalBytes: 2992000000000,  // ~2.72 TB used
  capacityBytes: 4400000000000, // ~4.00 TB total
  byType: StorageByType(
    movies: 1380000000000,
    tv: 980000000000,
    music: 340000000000,
    files: 292000000000,
  ),
);

// Activity timestamps are fixed relative to 2026-05-02T12:00:00Z.
// Events are 5 s, 2 m, 45 m, and 3 h before that anchor.
final _activities = [
  const ActivityEvent(
    id: 'evt-1',
    type: 'stream.start',
    summary: 'Device 1 started streaming Inception',
    createdAt: '2026-05-02T11:59:55.000Z', // 5s ago
  ),
  const ActivityEvent(
    id: 'evt-2',
    type: 'client.pair',
    summary: 'Device 3 paired successfully',
    createdAt: '2026-05-02T11:58:00.000Z', // 2m ago
  ),
  const ActivityEvent(
    id: 'evt-3',
    type: 'library.scan',
    summary: 'Movies library scan completed (42 new files)',
    createdAt: '2026-05-02T11:15:00.000Z', // 45m ago
  ),
  const ActivityEvent(
    id: 'evt-4',
    type: 'system',
    summary: 'Server started',
    createdAt: '2026-05-02T09:00:00.000Z', // 3h ago
  ),
];

// 30 deterministic CPU samples — gentle sine-ish wave around 18 %.
final _cpuSamples = List.generate(
  30,
  (i) => 10.0 + 16.0 * (0.5 + 0.5 * (i % 8 < 4 ? 1.0 : -1.0)),
);

const _sysStats = SystemStats(
  uptimeSeconds: 14400, // 4 h
  lanIp: '192.168.1.42',
  publicAddress: 'home.example.com',
  internetConnected: true,
  cpuPercent: 18.4,
  ramPercent: 42.1,
  ramUsedBytes: 8_800_000_000,
  ramTotalBytes: 21_000_000_000,
  networkInMbps: 8.4,
  networkOutMbps: 2.1,
  activeStreams: 1,
);

// ── Stub cubits ───────────────────────────────────────────────────────────────

/// A [DashboardCubit] that starts in the [DashboardLoaded] state without
/// hitting any real repository.
class _StubDashboardCubit extends DashboardCubit {
  _StubDashboardCubit(_MockDashboardRepo repo) : super(repository: repo);

  @override
  Future<void> load() async {
    emit(const DashboardLoading());
    emit(DashboardLoaded(
      serverInfo: _serverInfo,
      clients: _clients,
      libraryCount: 6,
    ));
  }
}

class _StubStorageCubit extends StorageCubit {
  _StubStorageCubit(_MockStorageRepo repo) : super(repository: repo);

  @override
  Future<void> load() async {
    emit(const StorageLoading());
    emit(const StorageLoaded(_storage));
  }
}

class _StubRecentActivityCubit extends RecentActivityCubit {
  _StubRecentActivityCubit(_MockActivityRepo repo) : super(repository: repo);

  @override
  Future<void> load() async {
    emit(const RecentActivityLoading());
    emit(RecentActivityLoaded(_activities));
  }
}

/// A [SystemStatsCubit] that emits a deterministic state without polling.
class _StubSystemStatsCubit extends SystemStatsCubit {
  _StubSystemStatsCubit(_MockSystemStatsRepo repo) : super(repository: repo);

  @override
  void start() {
    emit(SystemStatsState(
      latest: _sysStats,
      cpuSamples: _cpuSamples,
      ramSamples: List.filled(30, 42.1),
      netInSamples: List.filled(30, 8.4),
      netOutSamples: List.filled(30, 2.1),
    ));
  }

  @override
  Future<void> close() {
    stop();
    return super.close();
  }
}

// ── Golden test ───────────────────────────────────────────────────────────────

void main() {
  final mockDashboardRepo = _MockDashboardRepo();
  final mockStorageRepo = _MockStorageRepo();
  final mockActivityRepo = _MockActivityRepo();
  final mockSystemStatsRepo = _MockSystemStatsRepo();

  setUpAll(() async {
    await loadAppFonts();
  });

  testGoldens('DashboardScreen — m3 default state', (tester) async {
    final dashboardCubit = _StubDashboardCubit(mockDashboardRepo);
    final storageCubit = _StubStorageCubit(mockStorageRepo);
    final activityCubit = _StubRecentActivityCubit(mockActivityRepo);
    final systemStatsCubit = _StubSystemStatsCubit(mockSystemStatsRepo);

    await tester.pumpWidgetBuilder(
      MultiBlocProvider(
        providers: [
          BlocProvider<DashboardCubit>.value(value: dashboardCubit),
          BlocProvider<StorageCubit>.value(value: storageCubit),
          BlocProvider<RecentActivityCubit>.value(value: activityCubit),
          BlocProvider<SystemStatsCubit>.value(value: systemStatsCubit),
        ],
        child: const DashboardScreen(),
      ),
      surfaceSize: const Size(1440, 900),
    );

    // Trigger all stub loads.
    await dashboardCubit.load();
    storageCubit.load();
    activityCubit.load();
    systemStatsCubit.start();

    // Settle animations.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await screenMatchesGolden(tester, 'm3_dashboard_default');

    await dashboardCubit.close();
    await storageCubit.close();
    await activityCubit.close();
    await systemStatsCubit.close();
  });
}
