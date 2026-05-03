import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fluxora_core/entities/converters.dart';
import 'package:fluxora_core/entities/enums.dart';

part 'client_profile.freezed.dart';
part 'client_profile.g.dart';

/// Per-client profile from `GET /api/v1/auth/clients/me` (Phase A backfill).
///
/// `displayName` maps to the server's `display_name` (which is just the
/// existing `clients.name` column renamed in the API surface — the wire
/// field is `display_name`, deserialised here as `displayName`).
/// `email` and `pairedAt` may be null on clients paired before migration
/// 016 ran.  `tier` is read live from `user_settings.subscription_tier`
/// so a freshly-applied license upgrade reflects on the next refresh.
@freezed
abstract class ClientProfile with _$ClientProfile {
  const factory ClientProfile({
    required String id,
    @JsonKey(name: 'display_name') required String displayName,
    String? email,
    required ClientPlatform platform,
    @JsonKey(
      name: 'paired_at',
      fromJson: utcDateTimeOrNullFromJson,
      toJson: utcDateTimeOrNullToJson,
    )
    DateTime? pairedAt,
    @JsonKey(
      name: 'last_seen',
      fromJson: utcDateTimeFromJson,
      toJson: utcDateTimeToJson,
    )
    required DateTime lastSeen,
    required SubscriptionTier tier,
  }) = _ClientProfile;

  factory ClientProfile.fromJson(Map<String, dynamic> json) =>
      _$ClientProfileFromJson(json);
}
