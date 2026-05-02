import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity_event.freezed.dart';
part 'activity_event.g.dart';

/// A single server activity event returned by `GET /api/v1/activity`.
///
/// Backs the Dashboard "Recent Activity" card.
@freezed
abstract class ActivityEvent with _$ActivityEvent {
  const factory ActivityEvent({
    required String id,

    /// Category string e.g. 'stream.start', 'client.pair', 'storage', 'system'.
    required String type,

    /// 'client' | 'system' | 'operator' | null
    String? actorKind,
    String? actorId,
    String? targetKind,
    String? targetId,

    /// Human-readable summary shown in the activity row.
    required String summary,

    /// Arbitrary JSON payload attached to the event.
    Map<String, dynamic>? payload,

    /// ISO-8601 UTC timestamp.
    required String createdAt,
  }) = _ActivityEvent;

  factory ActivityEvent.fromJson(Map<String, dynamic> json) =>
      _$ActivityEventFromJson(json);
}
