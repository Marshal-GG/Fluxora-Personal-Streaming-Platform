import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_stats.freezed.dart';
part 'system_stats.g.dart';

/// Live system stats payload — mirrors the server's `SystemStatsResponse`.
///
/// Returned by `GET /api/v1/info/stats` and pushed every 1.1 s on
/// `WS /api/v1/ws/stats`. Backs the redesigned sidebar System Status block,
/// the bottom status bar, and the Dashboard sparklines.
@freezed
abstract class SystemStats with _$SystemStats {
  const factory SystemStats({
    required int uptimeSeconds,
    String? lanIp,
    String? publicAddress,
    required bool internetConnected,
    required double cpuPercent,
    required double ramPercent,
    required int ramUsedBytes,
    required int ramTotalBytes,
    required double networkInMbps,
    required double networkOutMbps,
    required int activeStreams,
  }) = _SystemStats;

  factory SystemStats.fromJson(Map<String, dynamic> json) =>
      _$SystemStatsFromJson(json);
}
