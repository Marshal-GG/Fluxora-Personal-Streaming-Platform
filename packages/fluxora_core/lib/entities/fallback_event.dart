import 'package:freezed_annotation/freezed_annotation.dart';

part 'fallback_event.freezed.dart';
part 'fallback_event.g.dart';

/// One encoder routing decision from `services/session_router.py`'s ring
/// buffer.  Drives the desktop's "Recent fallback events" diagnostic
/// panel — Slice C of the GPU UX plan.
///
/// `reason` values:
/// - `configured` — first chain entry was available; no fallback.
/// - `gpu_session_cap_hit` — first entry was at cap, fell to next.
/// - `all_encoders_saturated` — every entry at cap; using last anyway.
/// - `encoder_unknown` — every chain entry was a typo; using default.
@freezed
abstract class FallbackEvent with _$FallbackEvent {
  const factory FallbackEvent({
    required String timestamp,
    required String sessionId,
    required String requestedEncoder,
    required String actualEncoder,
    required String reason,
  }) = _FallbackEvent;

  factory FallbackEvent.fromJson(Map<String, dynamic> json) =>
      _$FallbackEventFromJson(json);
}

@freezed
abstract class FallbackHistory with _$FallbackHistory {
  const factory FallbackHistory({
    @Default([]) List<FallbackEvent> events,
  }) = _FallbackHistory;

  factory FallbackHistory.fromJson(Map<String, dynamic> json) =>
      _$FallbackHistoryFromJson(json);
}
