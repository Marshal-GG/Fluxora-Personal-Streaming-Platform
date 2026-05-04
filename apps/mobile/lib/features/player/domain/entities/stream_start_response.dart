class StreamStartResponse {
  const StreamStartResponse({
    required this.sessionId,
    required this.fileId,
    required this.playlistUrl,
    this.resumeSec = 0.0,
    this.hdrFormat,
    this.tonemapped = false,
  });

  final String sessionId;
  final String fileId;
  final String playlistUrl;
  final double resumeSec;

  /// Source HDR format from ffprobe at scan time:
  /// `"HDR10"` / `"HLG"` / `"DolbyVision"` / `null` (SDR).
  /// Drives the HDR badge in the player chrome — null hides the badge,
  /// any string shows it.
  final String? hdrFormat;

  /// True when the server is currently tonemapping HDR → SDR for this
  /// session (because the client passed `tonemap=true` and the source
  /// is HDR).  Drives the toggle's on/off state in the player UI.
  final bool tonemapped;

  factory StreamStartResponse.fromJson(Map<String, dynamic> json) =>
      StreamStartResponse(
        sessionId: json['session_id'] as String,
        fileId: json['file_id'] as String,
        playlistUrl: json['playlist_url'] as String,
        resumeSec: (json['resume_sec'] as num?)?.toDouble() ?? 0.0,
        hdrFormat: json['hdr_format'] as String?,
        tonemapped: json['tonemapped'] as bool? ?? false,
      );
}
