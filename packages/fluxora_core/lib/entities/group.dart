import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';
part 'group.g.dart';

enum GroupStatus {
  @JsonValue('active')
  active,
  @JsonValue('inactive')
  inactive,
}

@freezed
abstract class TimeWindow with _$TimeWindow {
  const factory TimeWindow({
    required int startH,
    required int endH,
    required List<int> days,
  }) = _TimeWindow;

  factory TimeWindow.fromJson(Map<String, dynamic> json) =>
      _$TimeWindowFromJson(json);
}

@freezed
abstract class GroupRestrictions with _$GroupRestrictions {
  const factory GroupRestrictions({
    List<String>? allowedLibraries,
    int? bandwidthCapMbps,
    TimeWindow? timeWindow,
    String? maxRating,
  }) = _GroupRestrictions;

  factory GroupRestrictions.fromJson(Map<String, dynamic> json) =>
      _$GroupRestrictionsFromJson(json);
}

@freezed
abstract class Group with _$Group {
  const factory Group({
    required String id,
    required String name,
    String? description,
    required GroupStatus status,
    required String createdAt,
    required String updatedAt,
    @Default(0) int memberCount,
    GroupRestrictions? restrictions,
  }) = _Group;

  factory Group.fromJson(Map<String, dynamic> json) => _$GroupFromJson(json);
}

/// Tiny summary of a group a client belongs to.  Returned per-client by
/// `GET /api/v1/auth/clients` (M3, 2026-05-07) so the desktop Clients
/// screen detail panel can render group-membership chips without a
/// second fetch.  Heavier fields (restrictions, memberCount, timestamps)
/// live on the dedicated [Group] entity returned by `/groups/{id}`.
@freezed
abstract class GroupSummary with _$GroupSummary {
  const factory GroupSummary({
    required String id,
    required String name,
    required GroupStatus status,
  }) = _GroupSummary;

  factory GroupSummary.fromJson(Map<String, dynamic> json) =>
      _$GroupSummaryFromJson(json);
}
