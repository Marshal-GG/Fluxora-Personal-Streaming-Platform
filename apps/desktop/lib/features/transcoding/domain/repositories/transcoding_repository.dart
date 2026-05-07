import 'package:fluxora_core/entities/encoder_advice.dart';
import 'package:fluxora_core/entities/encoder_benchmark.dart';
import 'package:fluxora_core/entities/fallback_event.dart';
import 'package:fluxora_core/entities/hardware_devices.dart';
import 'package:fluxora_core/entities/transcoding_status.dart';

abstract class TranscodingRepository {
  Future<TranscodingStatus> status();
  Future<EncoderAdvice> advisor();
  Future<HardwareDevices> devices();
  Future<FallbackHistory> fallbackHistory();

  /// Triggers a synthetic encode through every available encoder.
  ///
  /// Long-running on the server side (~5–10 s per hardware encoder, more for
  /// software).  Callers must use a long receive timeout — at least 90 s for
  /// a typical 3-encoder system.
  ///
  /// `durationSec` is clamped server-side to [2, 20]; null = server default
  /// (8 s).  `fps` is clamped to [24, 60]; null = server default (30).
  /// Higher fps roughly halves each encoder's realtime multiplier — useful
  /// for gauging 60 fps capability.
  ///
  /// `width` × `height` set the synthetic source resolution.  720p is the
  /// representative library-content default; 1080p models live game capture;
  /// 2160p (4K) tells the operator whether their hardware can drive 4K HDR
  /// transcodes.  Null on either dimension = server default (1280×720).
  ///
  /// The cap-verification probe is always on — without it the concurrent
  /// chip would lie about capacity (NVIDIA's documented cap of 3 doesn't
  /// apply to driver 530+ / RTX 40-series / patched cards).
  Future<EncoderBenchmarkRun> benchmark({
    int? durationSec,
    int? fps,
    int? width,
    int? height,
  });

  /// Live progress snapshot for an in-flight benchmark run.  Polled by
  /// the desktop while its own `benchmark()` POST is in flight so the
  /// operator sees per-encoder status instead of a featureless spinner.
  /// Returns `running=false` when no benchmark is in flight.
  Future<BenchmarkProgress> benchmarkProgress();

  /// List recent benchmark-run summaries for the history sidebar.  Newest
  /// first; the server caps `limit` at 50.
  Future<BenchmarkHistory> benchmarkHistory({int limit = 20});

  /// Fetch one stored run's full body (per-encoder results) by id.
  /// Throws when the id is unknown.
  Future<EncoderBenchmarkRun> benchmarkHistoryEntry(int id);

  /// Delete one stored run from history.
  Future<void> deleteBenchmarkHistoryEntry(int id);
}
