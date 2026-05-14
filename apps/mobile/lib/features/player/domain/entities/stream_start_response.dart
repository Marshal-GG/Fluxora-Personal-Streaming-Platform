/// Per-audio-track metadata returned by the server in `/stream/start`
/// (plan 22 §Server changes).  Each track is one entry in the source
/// container; the operator picks one via the Audio bottom-sheet and the
/// client tells media_kit to switch via `Player.setAudioTrack`.  No
/// server round-trip — server multiplexes every track in the fmp4 init
/// segment + segments, the picker is purely client-side.
///
/// JSON shape (server-side `AudioTrackInfo` model):
///   { "index": int, "codec": str, "language": str?, "title": str?,
///     "channels": int, "sample_rate": int, "bit_rate": int? }
class AudioTrackInfo {
  const AudioTrackInfo({
    required this.index,
    required this.codec,
    this.language,
    this.title,
    required this.channels,
    required this.sampleRate,
    this.bitRate,
  });

  /// FFmpeg source stream index (`0:a:<index>` in `-map` parlance).
  /// Stable for the lifetime of a session — the cubit stores this so
  /// the checkmark renders against the currently-selected track.
  final int index;

  /// Lower-case codec name from ffprobe (`aac`, `ac3`, `eac3`, etc.).
  final String codec;

  /// ISO 639 language tag (3-letter or 2-letter) if the source file
  /// declared `tags.language` on the stream — null for files that don't
  /// carry the tag (most home-grown captures, including NVIDIA Game Bar).
  final String? language;

  /// `tags.title` from ffprobe — typically present on commentary tracks
  /// ("Director Commentary") and movie remuxes ("English 5.1").  Null
  /// when the source omits it.
  final String? title;

  /// Channel count: 2 for stereo, 6 for 5.1, 8 for 7.1, etc.
  final int channels;

  /// Source sample rate in Hz (44100, 48000 typically).  Surfaced for
  /// diagnostics; not currently rendered in the picker row.
  final int sampleRate;

  /// Source bitrate in bps when ffprobe reports it.  Null for codecs
  /// where the container doesn't carry it (some MKVs).  Not currently
  /// rendered in the picker row.
  final int? bitRate;

  factory AudioTrackInfo.fromJson(Map<String, dynamic> json) => AudioTrackInfo(
    index: json['index'] as int,
    codec: json['codec'] as String,
    language: json['language'] as String?,
    title: json['title'] as String?,
    channels: json['channels'] as int,
    sampleRate: json['sample_rate'] as int,
    bitRate: json['bit_rate'] as int?,
  );

  /// User-facing label for the picker row.
  ///
  /// Format: `<identifier> · <channel-layout> · <codec-upper>`
  ///
  /// `identifier` resolution order:
  ///   1. `language` if non-null and non-empty — rendered as the raw
  ///      tag uppercased (e.g. `eng` → `ENG`).  There is no mobile-side
  ///      ISO 639 → display-name mapper today; if/when one lands we
  ///      swap this branch for it without changing the rule order.
  ///   2. `title` if non-null and non-empty (e.g. "Director Commentary").
  ///   3. Fallback `Track <N>` where `N = index + 1` (1-based for
  ///      human-readability — matches the audio_subs_sheet legacy
  ///      label).
  ///
  /// `channel-layout` formatting:
  ///   - 1 → `1.0`, 2 → `2.0`, 6 → `5.1`, 8 → `7.1`
  ///   - otherwise `<N> ch`
  ///
  /// The `BuildContext` parameter is accepted (and ignored today) so a
  /// future agent can switch to a localized language-name lookup
  /// without changing every call site.
  String labelFor(Object _) {
    final identifier = _resolveIdentifier();
    final channelLabel = _formatChannelLayout(channels);
    final codecUpper = codec.toUpperCase();
    return '$identifier · $channelLabel · $codecUpper';
  }

  String _resolveIdentifier() {
    final lang = language;
    if (lang != null && lang.isNotEmpty) {
      return lang.toUpperCase();
    }
    final t = title;
    if (t != null && t.isNotEmpty) {
      return t;
    }
    return 'Track ${index + 1}';
  }

  static String _formatChannelLayout(int channels) {
    switch (channels) {
      case 1:
        return '1.0';
      case 2:
        return '2.0';
      case 6:
        return '5.1';
      case 8:
        return '7.1';
      default:
        return '$channels ch';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AudioTrackInfo &&
        other.index == index &&
        other.codec == codec &&
        other.language == language &&
        other.title == title &&
        other.channels == channels &&
        other.sampleRate == sampleRate &&
        other.bitRate == bitRate;
  }

  @override
  int get hashCode =>
      Object.hash(index, codec, language, title, channels, sampleRate, bitRate);

  @override
  String toString() =>
      'AudioTrackInfo(index: $index, codec: $codec, language: $language, '
      'title: $title, channels: $channels, sampleRate: $sampleRate, '
      'bitRate: $bitRate)';
}

class StreamStartResponse {
  const StreamStartResponse({
    required this.sessionId,
    required this.fileId,
    required this.playlistUrl,
    this.resumeSec = 0.0,
    this.appliedSeekSec = 0.0,
    this.hdrFormat,
    this.tonemapped = false,
    this.streamingMode = 'client-decode',
    this.audioStreamingMode = 'transcode',
    this.audioTracks = const [],
  });

  final String sessionId;
  final String fileId;
  final String playlistUrl;
  final double resumeSec;

  /// Segment-aligned seek position FFmpeg actually started at — equals
  /// `floor(resumeSec / hls_time) * hls_time`.  The playlist's t=0
  /// corresponds to this source-time, NOT to t=0 of the file.  The
  /// cubit stores this as `_playlistOffsetSec` and adds it to libmpv's
  /// reported position when rendering the scrubber so the user sees
  /// source-time, not playlist-time (streaming pipeline plan §16
  /// scrubber-offset patch 2026-05-08).
  final double appliedSeekSec;

  /// Source HDR format from ffprobe at scan time:
  /// `"HDR10"` / `"HLG"` / `"DolbyVision"` / `null` (SDR).
  /// Drives the HDR badge in the player chrome — null hides the badge,
  /// any string shows it.
  final String? hdrFormat;

  /// True when the server is currently tonemapping HDR → SDR for this
  /// session (because the client passed `tonemap=true` and the source
  /// is HDR).  Drives the toggle's on/off state in the player UI.
  final bool tonemapped;

  /// Plan 20 — the operator's effective `streaming_mode` setting for
  /// this session.  Mobile uses it to decide whether to arm the
  /// auto-fallback watcher: only `'auto'` may trigger a fallback POST.
  /// Strict `'client-decode'` and `'server-transcode'` sessions ignore
  /// decode errors and surface them to the user as a normal failure.
  final String streamingMode;

  /// Plan 21 — server's effective audio-streaming decision for this
  /// session: `'stream-copy'` when the source audio codec is on the
  /// client allowlist (`{aac, ac3, eac3, opus, flac}` minus the
  /// per-client audio-codec blocklist), `'transcode'` otherwise.  Only
  /// meaningful when [streamingMode] is `'auto'` — the audio fallback
  /// watcher arms exclusively for `auto + stream-copy`.  Defaults to
  /// `'transcode'` so older servers (pre-plan-21) and any session that
  /// already re-encodes audio never trigger an audio-fallback POST.
  final String audioStreamingMode;

  /// Plan 22 — every audio track in the source file's container,
  /// returned alongside `/stream/start` so the mobile picker can list
  /// them without re-probing.  Defaults to `[]` for backward compat
  /// with pre-plan-22 servers: the Audio quick-action greys out when
  /// the list has 0-or-1 entries.  Track 0 is the default selection;
  /// the operator picks a different one via the picker which dispatches
  /// `Player.setAudioTrack` — no server round-trip.
  final List<AudioTrackInfo> audioTracks;

  factory StreamStartResponse.fromJson(Map<String, dynamic> json) =>
      StreamStartResponse(
        sessionId: json['session_id'] as String,
        fileId: json['file_id'] as String,
        playlistUrl: json['playlist_url'] as String,
        resumeSec: (json['resume_sec'] as num?)?.toDouble() ?? 0.0,
        appliedSeekSec: (json['applied_seek_sec'] as num?)?.toDouble() ?? 0.0,
        hdrFormat: json['hdr_format'] as String?,
        tonemapped: json['tonemapped'] as bool? ?? false,
        streamingMode: json['streaming_mode'] as String? ?? 'client-decode',
        audioStreamingMode:
            json['audio_streaming_mode'] as String? ?? 'transcode',
        audioTracks: _parseAudioTracks(json['audio_tracks']),
      );

  /// Defensive — skip entries that aren't dicts (server contract says
  /// they always are, but a future server-side bug shouldn't crash the
  /// player) and entries missing required scalar keys (the `as int` /
  /// `as String` casts inside `AudioTrackInfo.fromJson` would throw
  /// otherwise).  Missing key → empty list, matching the pre-plan-22
  /// default for backward compat.
  static List<AudioTrackInfo> _parseAudioTracks(Object? raw) {
    if (raw is! List) return const [];
    final out = <AudioTrackInfo>[];
    for (final entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      if (entry['index'] is! int ||
          entry['codec'] is! String ||
          entry['channels'] is! int ||
          entry['sample_rate'] is! int) {
        continue;
      }
      out.add(AudioTrackInfo.fromJson(entry));
    }
    return out;
  }
}
