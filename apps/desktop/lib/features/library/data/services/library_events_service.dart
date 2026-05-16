/// WebSocket subscriber for server-side library / storage sync events.
///
/// Replaces the periodic polling the cubits used to do.  The server's
/// `/api/v1/ws/notifications` channel broadcasts ephemeral `event`
/// frames (in addition to persistent notifications); this service
/// filters for `library_changed` / `storage_changed` kinds and exposes
/// them as broadcast streams the cubits subscribe to.
///
/// Wire format on the wire (server side):
///   {"type": "event", "kind": "library_changed"}
///   {"type": "event", "kind": "storage_changed"}
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

  /// Fires once per server-emitted `library_changed` event.
  Stream<void> get libraryChanged => _libraryChanged.stream;

  /// Fires once per server-emitted `storage_changed` event.
  Stream<void> get storageChanged => _storageChanged.stream;

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
