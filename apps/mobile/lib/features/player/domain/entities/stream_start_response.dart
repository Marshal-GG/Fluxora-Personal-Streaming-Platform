class StreamStartResponse {
  const StreamStartResponse({
    required this.sessionId,
    required this.fileId,
    required this.playlistUrl,
  });

  final String sessionId;
  final String fileId;
  final String playlistUrl;

  factory StreamStartResponse.fromJson(Map<String, dynamic> json) =>
      StreamStartResponse(
        sessionId: json['session_id'] as String,
        fileId: json['file_id'] as String,
        playlistUrl: json['playlist_url'] as String,
      );
}
