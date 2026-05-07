import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';
part 'group.g.dart';

enum GroupStatus {
  @JsonValue('active')
  active,
  @JsonValue('inactive')
  inactive,
}

/// PIN-mode on a gated group — `session` issues 12 h grants on unlock,
/// `perEntry` issues 5 min grants for adult / sensitive content where
/// every navigation should re-PIN.  Wire format mirrors the server enum
/// (`'session'` / `'per-entry'`).
enum PinMode {
  @JsonValue('session')
  session,
  @JsonValue('per-entry')
  perEntry,
}

/// Hybrid-PIN model on a gated group (M8).  `shared` is one PIN per
/// group, every member uses the same secret (M4 default behavior).
/// `perClient` is per-member device enrollment — each client sets and
/// remembers its own PIN; compromise blast radius is one device.  Wire
/// format mirrors the server enum (`'shared'` / `'per-client'`).
enum PinModel {
  @JsonValue('shared')
  shared,
  @JsonValue('per-client')
  perClient,
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

    /// v2 content-spaces fields (server migration 025).  All defaulted
    /// so a desktop binary built against an older server still parses
    /// the response shape.  See
    /// `docs/10_planning/13_groups_v2_content_spaces.md`.
    @Default(false) @JsonKey(name: 'is_public') bool isPublic,
    @Default(false) @JsonKey(name: 'requires_pin') bool requiresPin,
    @Default(PinMode.session) @JsonKey(name: 'pin_mode') PinMode pinMode,
    @Default(PinModel.shared) @JsonKey(name: 'pin_model') PinModel pinModel,
    String? icon,
    String? color,
    @JsonKey(name: 'max_concurrent_streams') int? maxConcurrentStreams,
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
