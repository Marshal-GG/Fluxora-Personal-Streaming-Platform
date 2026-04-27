import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fluxora_core/entities/converters.dart';
import 'package:fluxora_core/entities/enums.dart';

part 'stream_session.freezed.dart';
part 'stream_session.g.dart';

@freezed
class StreamSession with _$StreamSession {
  const factory StreamSession({
    required String id,
    required String fileId,
    required String clientId,
    @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
    required DateTime startedAt,
    @JsonKey(
      fromJson: utcDateTimeOrNullFromJson,
      toJson: utcDateTimeOrNullToJson,
    )
    DateTime? endedAt,
    required ConnectionType connectionType,
    int? bytesTransferred,
    double? progressSec,
  }) = _StreamSession;

  factory StreamSession.fromJson(Map<String, dynamic> json) =>
      _$StreamSessionFromJson(json);
}
