/// Unit tests for [ExoPlayerEngine].  Stubs both the MethodChannel
/// (Dart → Kotlin commands) and the EventChannel (Kotlin → Dart push)
/// with `flutter_test`'s built-in mock messenger so we can exercise
/// the Dart half of the engine without an Android platform side.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluxora_core/fluxora_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockMethodChannel methodMock;
  late _MockEventChannel eventMock;
  late MethodChannel methodChannel;
  late EventChannel eventChannel;

  setUp(() {
    methodChannel = const MethodChannel(kExoPlayerMethodChannel);
    eventChannel = const EventChannel(kExoPlayerEventChannel);
    methodMock = _MockMethodChannel(methodChannel);
    eventMock = _MockEventChannel(eventChannel);
  });

  tearDown(() async {
    methodMock.detach();
    eventMock.detach();
  });

  group('ExoPlayerEngine.create', () {
    test('returns an instance carrying the stubbed playerId and textureId',
        () async {
      methodMock.handler = (call) async {
        expect(call.method, 'create');
        return <String, dynamic>{'playerId': 7, 'textureId': 42};
      };

      final engine = await ExoPlayerEngine.createWithChannels(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );

      expect(engine.debugPlayerId, 7);
      expect(engine.textureId, 42);
      await engine.dispose();
    });

    test('throws when the platform returns no playerId', () async {
      methodMock.handler = (call) async => <String, dynamic>{};
      expect(
        () => ExoPlayerEngine.createWithChannels(
          methodChannel: methodChannel,
          eventChannel: eventChannel,
        ),
        throwsStateError,
      );
    });
  });

  group('EventChannel routing', () {
    test('position emissions reach positionStream + cached getter',
        () async {
      methodMock.handler = (call) async =>
          <String, dynamic>{'playerId': 0, 'textureId': 10};
      final engine = await ExoPlayerEngine.createWithChannels(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );

      final emitted = <Duration>[];
      final sub = engine.positionStream.listen(emitted.add);
      // Wait one microtask so listen() has registered before we push.
      await Future<void>.delayed(Duration.zero);

      eventMock.push(<String, dynamic>{
        'playerId': 0,
        'type': 'positionChanged',
        'positionMs': 1500,
      });
      eventMock.push(<String, dynamic>{
        'playerId': 0,
        'type': 'positionChanged',
        'positionMs': 1750,
      });

      // Let the EventChannel decoder drain.
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(
        emitted,
        equals(<Duration>[
          const Duration(milliseconds: 1500),
          const Duration(milliseconds: 1750),
        ]),
      );
      expect(engine.position, const Duration(milliseconds: 1750));
      await engine.dispose();
    });

    test('events for a different playerId are filtered out', () async {
      methodMock.handler = (call) async =>
          <String, dynamic>{'playerId': 5, 'textureId': 11};
      final engine = await ExoPlayerEngine.createWithChannels(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );

      final emitted = <Duration>[];
      final sub = engine.positionStream.listen(emitted.add);
      await Future<void>.delayed(Duration.zero);

      // playerId mismatch — must be dropped.
      eventMock.push(<String, dynamic>{
        'playerId': 99,
        'type': 'positionChanged',
        'positionMs': 9000,
      });
      // playerId match — must pass through.
      eventMock.push(<String, dynamic>{
        'playerId': 5,
        'type': 'positionChanged',
        'positionMs': 250,
      });

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emitted, equals(<Duration>[const Duration(milliseconds: 250)]));
      expect(engine.position, const Duration(milliseconds: 250));
      await engine.dispose();
    });

    test('durationChanged + isPlayingChanged update caches and streams',
        () async {
      methodMock.handler = (call) async =>
          <String, dynamic>{'playerId': 0, 'textureId': 1};
      final engine = await ExoPlayerEngine.createWithChannels(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );

      final durations = <Duration>[];
      final playings = <bool>[];
      final durSub = engine.durationStream.listen(durations.add);
      final playSub = engine.isPlayingStream.listen(playings.add);
      await Future<void>.delayed(Duration.zero);

      eventMock.push(<String, dynamic>{
        'playerId': 0,
        'type': 'durationChanged',
        'durationMs': 5400000,
      });
      eventMock.push(<String, dynamic>{
        'playerId': 0,
        'type': 'isPlayingChanged',
        'isPlaying': true,
      });

      await Future<void>.delayed(Duration.zero);
      await durSub.cancel();
      await playSub.cancel();

      expect(durations, equals(<Duration>[const Duration(milliseconds: 5400000)]));
      expect(playings, equals(<bool>[true]));
      expect(engine.duration, const Duration(milliseconds: 5400000));
      expect(engine.isPlaying, isTrue);
      await engine.dispose();
    });

    test('tracksChanged populates availableAudioTrackIndices + selection',
        () async {
      methodMock.handler = (call) async =>
          <String, dynamic>{'playerId': 0, 'textureId': 1};
      final engine = await ExoPlayerEngine.createWithChannels(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );

      final selections = <int?>[];
      final sub = engine.selectedAudioTrackStream.listen(selections.add);
      await Future<void>.delayed(Duration.zero);

      eventMock.push(<String, dynamic>{
        'playerId': 0,
        'type': 'tracksChanged',
        'audioTracks': <Map<String, dynamic>>[
          <String, dynamic>{
            'sourceIndex': 0,
            'language': 'eng',
            'channels': 6,
            'codec': 'ac3',
          },
          <String, dynamic>{
            'sourceIndex': 1,
            'language': 'hin',
            'channels': 2,
            'codec': 'aac',
          },
        ],
        'selectedAudioSourceIndex': 1,
      });

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(engine.availableAudioTrackIndices, equals(<int>[0, 1]));
      expect(engine.selectedAudioTrackIndex, 1);
      expect(selections, equals(<int?>[1]));
      await engine.dispose();
    });
  });

  group('Error mapping', () {
    test('decoder_failed maps to EngineError.decode', () async {
      methodMock.handler = (call) async =>
          <String, dynamic>{'playerId': 0, 'textureId': 1};
      final engine = await ExoPlayerEngine.createWithChannels(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );

      final received = <EngineErrorEvent>[];
      final sub = engine.errorStream.listen(received.add);
      await Future<void>.delayed(Duration.zero);

      eventMock.push(<String, dynamic>{
        'playerId': 0,
        'type': 'playerError',
        'errorCode': 'decoder_failed',
        'message': 'HEVC decoder init failed',
      });

      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, hasLength(1));
      expect(received.first.type, EngineError.decode);
      expect(received.first.message, 'HEVC decoder init failed');
      expect(received.first.cause, 'decoder_failed');
      await engine.dispose();
    });

    test('every documented error code maps to its EngineError bucket',
        () async {
      methodMock.handler = (call) async =>
          <String, dynamic>{'playerId': 0, 'textureId': 1};
      final engine = await ExoPlayerEngine.createWithChannels(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );

      final received = <EngineErrorEvent>[];
      final sub = engine.errorStream.listen(received.add);
      await Future<void>.delayed(Duration.zero);

      const expectations = <String, EngineError>{
        'auth_failed': EngineError.auth,
        'network_error': EngineError.network,
        'decoder_failed': EngineError.decode,
        'format_unsupported': EngineError.formatUnsupported,
        'unknown': EngineError.generic,
        'something_else': EngineError.generic, // unrecognised → generic
      };

      for (final code in expectations.keys) {
        eventMock.push(<String, dynamic>{
          'playerId': 0,
          'type': 'playerError',
          'errorCode': code,
          'message': null,
        });
      }
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received.map((e) => e.type).toList(),
          equals(expectations.values.toList()));
      await engine.dispose();
    });
  });

  group('Commands', () {
    test('setVolume converts 0-100 → 0-1 and passes playerId', () async {
      methodMock.handler = (call) async {
        if (call.method == 'create') {
          return <String, dynamic>{'playerId': 3, 'textureId': 0};
        }
        return null;
      };

      final engine = await ExoPlayerEngine.createWithChannels(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );

      methodMock.calls.clear();
      await engine.setVolume(50.0);

      expect(methodMock.calls, hasLength(1));
      expect(methodMock.calls.first.method, 'setVolume');
      final args =
          Map<String, dynamic>.from(methodMock.calls.first.arguments as Map);
      expect(args['playerId'], 3);
      expect(args['volume0to1'], closeTo(0.5, 1e-9));
      expect(engine.volume, 50.0);
      await engine.dispose();
    });

    test('open / play / pause / seek / setAudioTrack / setRate '
        'all carry playerId and the documented args', () async {
      methodMock.handler = (call) async {
        if (call.method == 'create') {
          return <String, dynamic>{'playerId': 1, 'textureId': 4};
        }
        return null;
      };

      final engine = await ExoPlayerEngine.createWithChannels(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );
      methodMock.calls.clear();

      await engine.open(
        'http://x/y.m3u8',
        headers: <String, String>{'Authorization': 'Bearer t'},
        play: true,
      );
      await engine.play();
      await engine.pause();
      await engine.seek(const Duration(seconds: 12));
      await engine.setAudioTrack(1);
      await engine.setRate(2.0);

      final byMethod = <String, MethodCall>{
        for (final c in methodMock.calls) c.method: c,
      };

      Map<String, dynamic> argsOf(String method) =>
          Map<String, dynamic>.from(byMethod[method]!.arguments as Map);

      expect(argsOf('open')['playerId'], 1);
      expect(argsOf('open')['url'], 'http://x/y.m3u8');
      expect(argsOf('open')['play'], true);
      expect(argsOf('open')['startPositionMs'], 0);
      expect(
        Map<String, String>.from(argsOf('open')['headers'] as Map),
        equals({'Authorization': 'Bearer t'}),
      );
      expect(argsOf('play')['playerId'], 1);
      expect(argsOf('pause')['playerId'], 1);
      expect(argsOf('seek')['positionMs'], 12000);
      expect(argsOf('setAudioTrack')['sourceIndex'], 1);
      expect(argsOf('setRate')['rate'], 2.0);
      expect(engine.rate, 2.0);

      // setAudioTrack also pre-caches the optimistic selection.
      expect(engine.selectedAudioTrackIndex, 1);

      await engine.dispose();
    });
  });

  group('Dispose', () {
    test('dispose invokes the native dispose, cancels the event sub, '
        'and closes every controller', () async {
      var disposeSeen = false;
      methodMock.handler = (call) async {
        if (call.method == 'create') {
          return <String, dynamic>{'playerId': 0, 'textureId': 0};
        }
        if (call.method == 'dispose') {
          disposeSeen = true;
          return null;
        }
        return null;
      };

      final engine = await ExoPlayerEngine.createWithChannels(
        methodChannel: methodChannel,
        eventChannel: eventChannel,
      );

      await engine.dispose();
      expect(disposeSeen, isTrue);

      // After dispose, the streams should be closed — listening yields
      // a done event without any data.
      expect(engine.positionStream.isBroadcast, isTrue);
      // A late listener on a closed broadcast controller gets a done
      // event; toList() resolves with an empty list.
      final tail = await engine.positionStream.toList().timeout(
            const Duration(seconds: 1),
            onTimeout: () => <Duration>[const Duration(seconds: -1)],
          );
      expect(tail, isEmpty);

      // Calling dispose() again is a no-op.
      disposeSeen = false;
      await engine.dispose();
      expect(disposeSeen, isFalse);
    });
  });
}

/// Adapter around `flutter_test`'s mock method-channel handler that
/// also remembers every call for assertion convenience.
class _MockMethodChannel {
  _MockMethodChannel(this._channel) {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, _onCall);
  }

  final MethodChannel _channel;
  final List<MethodCall> calls = <MethodCall>[];
  Future<Object?> Function(MethodCall call)? handler;

  Future<Object?> _onCall(MethodCall call) async {
    calls.add(call);
    final h = handler;
    if (h == null) return null;
    return h(call);
  }

  void detach() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

/// Adapter around `flutter_test`'s mock stream-handler that lets a
/// test push arbitrary payloads through a [EventChannel] as if the
/// platform had emitted them.
class _MockEventChannel {
  _MockEventChannel(this._channel) {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockStreamHandler(_channel, _Handler(this));
  }

  final EventChannel _channel;
  final List<Object?> _buffered = <Object?>[];
  MockStreamHandlerEventSink? _sink;

  void push(Object? event) {
    final s = _sink;
    if (s == null) {
      _buffered.add(event);
    } else {
      s.success(event);
    }
  }

  void _attachSink(MockStreamHandlerEventSink sink) {
    _sink = sink;
    for (final ev in _buffered) {
      sink.success(ev);
    }
    _buffered.clear();
  }

  void _detachSink() {
    _sink = null;
  }

  void detach() {
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockStreamHandler(_channel, null);
  }
}

class _Handler extends MockStreamHandler {
  _Handler(this._owner);

  final _MockEventChannel _owner;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) {
    _owner._attachSink(events);
  }

  @override
  void onCancel(Object? arguments) {
    _owner._detachSink();
  }
}
