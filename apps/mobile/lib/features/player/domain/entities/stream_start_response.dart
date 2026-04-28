class StreamStartResponse {
  const StreamStartResponse({
    required this.sessionId,
    required this.fileId,
    required this.playlistUrl,
    this.resumeSec = 0.0,
  });

  final String sessionId;
  final String fileId;
  final String playlistUrl;
  final double resumeSec;

  factory StreamStartResponse.fromJson(Map<String, dynamic> json) =>
      StreamStartResponse(
        sessionId: json['session_id'] as String,
        fileId: json['file_id'] as String,
        playlistUrl: json['playlist_url'] as String,
        resumeSec: (json['resume_sec'] as num?)?.toDouble() ?? 0.0,
      );
}
