import 'dart:async';
import 'dart:convert';
import 'dart:io' show WebSocket;

import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';

/// The current state of the WebRTC signaling channel.
enum SignalingState {
  /// Not yet connected.
  idle,

  /// WebSocket connected; SDP negotiation in progress.
  connecting,

  /// ICE connected — peer-to-peer data channel is live.
  connected,

  /// Connection failed or was closed unexpectedly.
  failed,

  /// Cleanly closed by the client.
  closed,
}

/// Callback fired whenever [SignalingState] changes.
typedef OnSignalingState = void Function(SignalingState state);

/// Callback fired when a local ICE candidate is ready to send.
typedef OnLocalCandidate = void Function(RTCIceCandidate candidate);

/// Manages one WebRTC session with the Fluxora server.
///
/// Lifecycle:
///   1. [connect] — opens the WebSocket and sends the auth token.
///   2. On [auth_ok] — creates an [RTCPeerConnection], generates an SDP offer,
///      and sends it to the server.
///   3. On [answer] — sets the remote description; ICE negotiation begins.
///   4. ICE candidates are exchanged via [ice-candidate] messages.
///   5. [close] tears everything down cleanly.
class WebRtcSignalingService {
  WebRtcSignalingService({
    required String serverWsUrl,
    required String authToken,
    this.onStateChange,
  })  : _serverWsUrl = serverWsUrl,
        _authToken = authToken;

  final String _serverWsUrl;
  final String _authToken;

  /// Caller is notified whenever the state transitions.
  final OnSignalingState? onStateChange;

  static final _log = Logger();

  // ── internals ──────────────────────────────────────────────────────────────
  WebSocket? _socket;
  RTCPeerConnection? _pc;
  SignalingState _state = SignalingState.idle;
  bool _closed = false;

  SignalingState get state => _state;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Opens the signaling WebSocket and begins the SDP offer/answer exchange.
  ///
  /// Completes when [SignalingState.connected] is reached or throws on failure.
  Future<void> connect() async {
    if (_state != SignalingState.idle) return;
    _setState(SignalingState.connecting);

    try {
      final wsUrl = _signalUrl();
      _log.d('[WebRTC] Connecting to $wsUrl');
      _socket = await WebSocket.connect(wsUrl);
      _socket!.listen(
        _onMessage,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: false,
      );

      // Step 1 — authenticate
      _send({'type': 'auth', 'token': _authToken});
    } catch (e, st) {
      _log.e('[WebRTC] WebSocket connect failed', error: e, stackTrace: st);
      _setState(SignalingState.failed);
      rethrow;
    }
  }

  /// Tears down the peer connection and WebSocket cleanly.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _setState(SignalingState.closed);
    await _pc?.close();
    _pc = null;
    await _socket?.close();
    _socket = null;
  }

  // ---------------------------------------------------------------------------
  // Internal — WebSocket message handling
  // ---------------------------------------------------------------------------

  void _onMessage(dynamic raw) {
    if (_closed) return;
    Map<String, dynamic> msg;
    try {
      msg = jsonDecode(raw as String) as Map<String, dynamic>;
    } catch (e) {
      _log.w('[WebRTC] Received invalid JSON: $raw');
      return;
    }

    final type = msg['type'] as String?;
    _log.d('[WebRTC] ← $type');

    switch (type) {
      case 'auth_ok':
        _onAuthOk();
      case 'answer':
        _onAnswer(msg['sdp'] as String);
      case 'ice-candidate':
        _onRemoteCandidate(msg);
      case 'error':
        _log.e('[WebRTC] Server error: ${msg['code']} — ${msg['detail']}');
        _setState(SignalingState.failed);
      default:
        _log.w('[WebRTC] Unknown message type: $type');
    }
  }

  void _onSocketError(Object error) {
    _log.e('[WebRTC] WebSocket error: $error');
    _setState(SignalingState.failed);
  }

  void _onSocketDone() {
    if (_state != SignalingState.closed) {
      _log.w('[WebRTC] WebSocket closed unexpectedly');
      _setState(SignalingState.failed);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — signaling steps
  // ---------------------------------------------------------------------------

  Future<void> _onAuthOk() async {
    try {
      _pc = await _createPeerConnection();
      final offer = await _pc!.createOffer();
      await _pc!.setLocalDescription(offer);
      _log.d('[WebRTC] → offer');
      _send({'type': 'offer', 'sdp': offer.sdp});
    } catch (e, st) {
      _log.e('[WebRTC] Offer creation failed', error: e, stackTrace: st);
      _setState(SignalingState.failed);
    }
  }

  Future<void> _onAnswer(String sdp) async {
    try {
      await _pc?.setRemoteDescription(
        RTCSessionDescription(sdp, 'answer'),
      );
      _log.d('[WebRTC] Remote description set');
      // ICE will proceed from here; _onIceConnectionState handles the transition.
    } catch (e, st) {
      _log.e('[WebRTC] setRemoteDescription failed', error: e, stackTrace: st);
      _setState(SignalingState.failed);
    }
  }

  Future<void> _onRemoteCandidate(Map<String, dynamic> msg) async {
    try {
      final candidate = RTCIceCandidate(
        msg['candidate'] as String,
        msg['sdpMid'] as String?,
        msg['sdpMLineIndex'] as int?,
      );
      await _pc?.addCandidate(candidate);
    } catch (e, st) {
      _log.w('[WebRTC] addCandidate failed', error: e, stackTrace: st);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal — RTCPeerConnection setup
  // ---------------------------------------------------------------------------

  Future<RTCPeerConnection> _createPeerConnection() async {
    final config = <String, dynamic>{
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ],
      'sdpSemantics': 'unified-plan',
    };

    final pc = await createPeerConnection(config);

    // Forward local ICE candidates to the server
    pc.onIceCandidate = (candidate) {
      if (_closed) return;
      _log.d('[WebRTC] → ice-candidate');
      _send({
        'type': 'ice-candidate',
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onIceConnectionState = (state) {
      _log.d('[WebRTC] ICE state: $state');
      switch (state) {
        case RTCIceConnectionState.RTCIceConnectionStateConnected:
        case RTCIceConnectionState.RTCIceConnectionStateCompleted:
          _setState(SignalingState.connected);
        case RTCIceConnectionState.RTCIceConnectionStateFailed:
          _setState(SignalingState.failed);
        case RTCIceConnectionState.RTCIceConnectionStateDisconnected:
          if (_state == SignalingState.connected) {
            _setState(SignalingState.failed);
          }
        default:
          break;
      }
    };

    return pc;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  void _send(Map<String, dynamic> payload) {
    final raw = jsonEncode(payload);
    _log.d('[WebRTC] → ${payload['type']}');
    _socket?.add(raw);
  }

  void _setState(SignalingState next) {
    if (_state == next) return;
    _state = next;
    _log.d('[WebRTC] State: $next');
    onStateChange?.call(next);
  }

  /// Converts the HTTP base URL to a WebSocket signal URL.
  ///
  /// e.g. `http://192.168.1.5:8000` → `ws://192.168.1.5:8000/api/v1/ws/signal`
  String _signalUrl() {
    final base = _serverWsUrl
        .replaceFirst(RegExp(r'^https'), 'wss')
        .replaceFirst(RegExp(r'^http'), 'ws');
    return '$base/api/v1/ws/signal';
  }
}
