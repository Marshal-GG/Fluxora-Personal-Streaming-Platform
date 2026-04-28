import 'package:freezed_annotation/freezed_annotation.dart';

enum LibraryType {
  @JsonValue('movies')
  movies,
  @JsonValue('tv')
  tv,
  @JsonValue('music')
  music,
  @JsonValue('files')
  files,
}

enum ConnectionType {
  @JsonValue('lan')
  lan,
  @JsonValue('webrtc_p2p')
  webrtcP2p,
  @JsonValue('turn_relay')
  turnRelay,
}

enum ClientPlatform {
  @JsonValue('android')
  android,
  @JsonValue('ios')
  ios,
  @JsonValue('windows')
  windows,
  @JsonValue('macos')
  macos,
  @JsonValue('linux')
  linux,
}

enum ClientStatus {
  pending,
  approved,
  rejected;

  static ClientStatus fromJson(String value) => switch (value) {
        'approved' => ClientStatus.approved,
        'rejected' => ClientStatus.rejected,
        _ => ClientStatus.pending,
      };

  String toJson() => name;
}

enum SubscriptionTier {
  @JsonValue('free')
  free,
  @JsonValue('plus')
  plus,
  @JsonValue('pro')
  pro,
  @JsonValue('ultimate')
  ultimate,
}
