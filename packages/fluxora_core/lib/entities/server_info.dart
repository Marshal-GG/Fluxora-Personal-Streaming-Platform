import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:fluxora_core/entities/enums.dart';

part 'server_info.freezed.dart';
part 'server_info.g.dart';

@freezed
abstract class ServerInfo with _$ServerInfo {
  const factory ServerInfo({
    required String serverName,
    required String version,
    required SubscriptionTier tier,
    String? remoteUrl,
  }) = _ServerInfo;

  factory ServerInfo.fromJson(Map<String, dynamic> json) =>
      _$ServerInfoFromJson(json);
}
