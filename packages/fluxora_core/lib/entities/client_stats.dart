import 'package:freezed_annotation/freezed_annotation.dart';

part 'client_stats.freezed.dart';
part 'client_stats.g.dart';

/// Per-client watch stats from `GET /auth/clients/me/stats` (Phase B
/// backfill plan §3 row 3).
///
/// All three values are non-negative integers and degrade gracefully —
/// a fresh client with no stream sessions returns `{0, 0, 0}` rather
/// than 404.  `shows` will stay at 0 until Phase D back-fills the
/// `tmdb_show_id` column on TV episode rows; that's intentional honesty
/// rather than a guessed-up number.
@freezed
abstract class ClientStats with _$ClientStats {
  const factory ClientStats({
    required int hours,
    required int movies,
    required int shows,
  }) = _ClientStats;

  factory ClientStats.fromJson(Map<String, dynamic> json) =>
      _$ClientStatsFromJson(json);
}
