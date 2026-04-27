import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fluxora_core/entities/converters.dart';
import 'package:fluxora_core/entities/enums.dart';

part 'client.freezed.dart';
part 'client.g.dart';

@freezed
class Client with _$Client {
  const factory Client({
    required String id,
    required String name,
    required ClientPlatform platform,
    @JsonKey(fromJson: utcDateTimeFromJson, toJson: utcDateTimeToJson)
    required DateTime lastSeen,
    required bool isTrusted,
    String? authToken,
  }) = _Client;

  factory Client.fromJson(Map<String, dynamic> json) =>
      _$ClientFromJson(json);
}
