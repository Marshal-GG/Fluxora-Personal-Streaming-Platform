/// WebSocket subscriber for server-side library / storage sync events.
///
/// Replaces the periodic polling the cubits used to do.  The server's
/// `/api/v1/ws/notifications` channel broadcasts ephemeral `event`
/// frames (in addition to persistent notifications); this service
/// filters for `library_changed` / `storage_changed` /
/// `thumbnails_progress` kinds and exposes them as broadcast streams
/// the cubits subscribe to.
///
/// Wire format on the wire (server side):
///   {"type": "event", "kind": "library_changed"}
///   {"type": "event", "kind": "storage_changed"}
///   {"type": "event", "kind": "thumbnails_progress",
///    "data": {"library_id": "...", "pending": N, "ready": M, "total": T}}
///
/// Connection lifecycle:
///   - `start()` opens the WS.  Idempotent.
///   - On disconnect / error, reconnects with exponential backoff
///     (1s, 2s, 4s, 8s, 16s, capped at 30s).
///   - `stop()` cancels reconnects and closes the socket.
///
/// Auth: skipped — the desktop only connects to localhost.  Remote
/// (cloudflared-tunnelled) deployments would need a first-message
/// `{"type":"auth","token":"…"}` handshake; future work if non-localhost
/// becomes a real use case.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logger/logger.dart';

class LibraryEventsService {
  LibraryEventsService({required this.wsUrl});

  final String wsUrl;
  static final _log = Logger();

  WebSocket? _socket;
  Timer? _reconnectTimer;
  Duration _backoff = const Duration(seconds: 1);
  bool _stopped = false;

  final _libraryChanged = StreamController<void>.broadcast();
  final _storageChanged = StreamController<void>.broadcast();
  final _thumbnailsProgress = StreamController<ThumbnailProgress>.broadcast();

  /// Fires once per server-emitted `library_changed` event.
  Stream<void> get libraryChanged => _libraryChanged.stream;

  /// Fires once per server-emitted `storage_changed` event.
  Stream<void> get storageChanged => _storageChanged.stream;

  /// Fires for every `thumbnails_progress` event emitted by the
  /// server-side thumbnail worker.  Carries the per-library pending /
  /// ready / total counts so the cubit can drive the in-progress chip
  /// on each library card.  Frequency: one event per worker completion
  /// (typically 1–2 / s under default CONCURRENCY=2).
  Stream<ThumbnailProgress> get thumbnailsProgress =>
      _thumbnailsProgress.stream;

  Future<void> start() async {
    _stopped = false;
    if (_socket != null) return;
    await _connect();
  }

  Future<void> stop() async {
    _stopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      await _socket?.close();
    } catch (_) {/* best-effort */}
    _socket = null;
  }

  Future<void> _connect() async {
    if (_stopped) return;
    try {
      // The socket is stored in `_socket` and closed in `stop()` — the
      // `close_sinks` lint can't follow field-stored connections.
      // ignore: close_sinks
      final socket = await WebSocket.connect(wsUrl);
      _socket = socket;
      _backoff = const Duration(seconds: 1);
      _log.i('LibraryEventsService connected: $wsUrl');
      socket.listen(
        _handleFrame,
        onDone: _scheduleReconnect,
        onError: (Object e, StackTrace st) {
          _log.w('LibraryEventsService stream error',
              error: e, stackTrace: st);
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e, st) {
      _log.w(
        'LibraryEventsService connect failed; '
        'retry in ${_backoff.inSeconds}s',
        error: e,
        stackTrace: st,
      );
      _scheduleReconnect();
    }
  }

  void _handleFrame(dynamic data) {
    if (data is! String) return;
    try {
      final json = jsonDecode(data) as Map<String, dynamic>;
      if (json['type'] != 'event') return;
      final kind = json['kind'] as String?;
      switch (kind) {
        case 'library_changed':
          _libraryChanged.add(null);
        case 'storage_changed':
          _storageChanged.add(null);
        case 'thumbnails_progress':
          final payload = json['data'];
          if (payload is Map<String, dynamic>) {
            final progress = ThumbnailProgress.tryParse(payload);
            if (progress != null) _thumbnailsProgress.add(progress);
          }
      }
    } catch (e, st) {
      _log.w('LibraryEventsService failed to parse frame',
          error: e, stackTrace: st);
    }
  }

  void _scheduleReconnect() {
    _socket = null;
    if (_stopped) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_backoff, _connect);
    // Exponential backoff with a 30 s cap.
    final nextSec = _backoff.inSeconds * 2;
    _backoff = Duration(seconds: nextSec > 30 ? 30 : nextSec);
  }

  Future<void> dispose() async {
    await stop();
    await _libraryChanged.close();
    await _storageChanged.close();
    await _thumbnailsProgress.close();
  }
}

/// Per-library thumbnail-generation progress snapshot, carried on
/// `thumbnails_progress` WS frames.  `pending` includes rows in both
/// `pending` and `generating` server-side status so the bar counts
/// claim-but-not-done work as outstanding.
class ThumbnailProgress {
  const ThumbnailProgress({
    required this.libraryId,
    required this.pending,
    required this.ready,
    required this.total,
  });

  final String libraryId;
  final int pending;
  final int ready;
  final int total;

  /// True when there are no longer any pending or generating rows for
  /// this library — the cubit / card can hide the chip.
  bool get isComplete => pending <= 0;

  /// Returns null on any shape mismatch instead of throwing — the WS
  /// frame parser swallows it so a malformed payload doesn't crash the
  /// listener.
  static ThumbnailProgress? tryParse(Map<String, dynamic> json) {
    final libraryId = json['library_id'];
    final pending = json['pending'];
    final ready = json['ready'];
    final total = json['total'];
    if (libraryId is! String ||
        pending is! int ||
        ready is! int ||
        total is! int) {
      return null;
    }
    return ThumbnailProgress(
      libraryId: libraryId,
      pending: pending,
      ready: ready,
      total: total,
    );
  }
}

/// Construct the WS URL from a base HTTP(S) URL.
///
/// `http://localhost:8000` → `ws://localhost:8000/api/v1/ws/notifications`
/// `https://example.com`  → `wss://example.com/api/v1/ws/notifications`
String libraryEventsWsUrl(String baseUrl) {
  final uri = Uri.parse(baseUrl);
  final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
  return Uri(
    scheme: wsScheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: '/api/v1/ws/notifications',
  ).toString();
}
