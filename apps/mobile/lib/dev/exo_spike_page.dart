// TODO(plan-24-M9): remove this dev spike page.
//
// Throwaway widget for Plan 24 M1 — validates the Android ExoPlayer
// MethodChannel + SurfaceProducer plumbing end-to-end before we invest
// in the `PlayerEngine` abstraction (M2) and the full Kotlin module
// (M4).  No cubit, no DI, no routing chrome — just a hard-coded HLS URL
// field, an Open button, and the returned texture.
//
// `debugPrint` is used (in violation of CLAUDE.md Hard Prohibition #3)
// because this file lives under `lib/dev/` and is gated behind the
// hidden `/dev/exo-spike` deep-link route below — production builds
// never surface it, and the whole file is deleted in M9.  If the
// project gains a globally-accessible `Logger` singleton between now
// and then, swap `debugPrint` for that.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hidden dev route — Plan 24 M1.  Not surfaced in any navigation UI.
const String kExoSpikeRoute = '/dev/exo-spike';

/// Default HLS test stream used when the operator opens the spike
/// without typing anything.  Apple's public BipBop sample — small,
/// well-formed, AAC stereo, single rendition — exactly what we want
/// for proving the surface + decoder hand-off works before pointing
/// the spike at a real Fluxora session URL.
const String _kDefaultHlsUrl =
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbopall/bipbopall.m3u8';

const MethodChannel _channel =
    MethodChannel('dev.marshalx.fluxora/exo_player');

class ExoSpikePage extends StatefulWidget {
  const ExoSpikePage({super.key});

  @override
  State<ExoSpikePage> createState() => _ExoSpikePageState();
}

class _ExoSpikePageState extends State<ExoSpikePage> {
  late final TextEditingController _urlController;
  int? _textureId;
  String _status = 'Idle.';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _kDefaultHlsUrl);
  }

  @override
  void dispose() {
    // Best-effort teardown so we don't leak the Kotlin ExoPlayer when
    // the operator navigates away.
    unawaited(_invoke('dispose'));
    _urlController.dispose();
    super.dispose();
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    debugPrint('[ExoSpike] -> $method args=$args');
    try {
      final result = await _channel.invokeMethod<T>(method, args);
      debugPrint('[ExoSpike] <- $method result=$result');
      return result;
    } on PlatformException catch (e) {
      debugPrint(
          '[ExoSpike] !! $method failed code=${e.code} message=${e.message}');
      if (mounted) {
        setState(() {
          _status = 'Error from $method: ${e.code} — ${e.message}';
        });
      }
      return null;
    } catch (e, st) {
      debugPrint('[ExoSpike] !! $method threw $e\n$st');
      if (mounted) {
        setState(() {
          _status = 'Unhandled error from $method: $e';
        });
      }
      return null;
    }
  }

  Future<void> _onOpen() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = 'Opening...';
    });
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _busy = false;
        _status = 'URL is empty.';
      });
      return;
    }
    final id = await _invoke<int>('open', <String, dynamic>{
      'url': url,
      // M1 carries no real auth headers — M4 wires the bearer token.
      'headers': <String, String>{},
    });
    if (!mounted) return;
    setState(() {
      _textureId = id;
      _busy = false;
      _status =
          id == null ? 'Open returned null.' : 'Texture id=$id (playing).';
    });
  }

  Future<void> _onPlay() async => _invoke('play');
  Future<void> _onPause() async => _invoke('pause');

  Future<void> _onDispose() async {
    await _invoke('dispose');
    if (!mounted) return;
    setState(() {
      _textureId = null;
      _status = 'Disposed.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final tex = _textureId;
    return Scaffold(
      appBar: AppBar(title: const Text('ExoPlayer spike (Plan 24 M1)')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'HLS URL',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(fontFamily: 'monospace'),
                maxLines: 2,
                minLines: 1,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _onOpen,
                      child: const Text('Open'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: tex == null ? null : _onDispose,
                    child: const Text('Dispose'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 240,
                child: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: tex == null
                      ? const Text(
                          'No texture yet — tap Open.',
                          style: TextStyle(color: Colors.white54),
                        )
                      : Texture(textureId: tex),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: tex == null ? null : _onPlay,
                      child: const Text('Play'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: tex == null ? null : _onPause,
                      child: const Text('Pause'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _status,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiny stand-in for `dart:async`'s `unawaited` so we don't pull in the
/// import just for this throwaway widget.
void unawaited(Future<void> f) {
  // ignore: avoid_empty_blocks
  f.then((_) {}, onError: (_) {});
}
