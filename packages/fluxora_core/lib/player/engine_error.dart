/// Structured error categories emitted by [PlayerEngine.errorStream].
///
/// Each engine implementation maps its native error space into one of
/// these values so the cubit's failure-reason logic doesn't have to
/// branch on libmpv-vs-ExoPlayer specifics.  The categories cover the
/// failure modes the cubit cares about today (auth + network gates,
/// decode/format fallbacks); anything else funnels into [generic].
library;

/// The engine-side error categories the cubit cares about.
///
/// Mappings (provisional):
/// - [auth] — HTTP 401 / 403 from segment fetches (rotated bearer).
/// - [network] — DNS / TCP / TLS / timeout / segment 5xx.
/// - [decode] — codec decoder failed for an otherwise reachable stream
///   (e.g. AV1 on a device with no hardware AV1 decoder).
/// - [formatUnsupported] — container / playlist parsing failed before a
///   decoder was even reached (malformed fmp4 init, bad HLS playlist).
/// - [generic] — anything that doesn't cleanly fit above.  The error
///   message is still passed through on [EngineErrorEvent.message] so a
///   diagnosing operator has something to grep for.
enum EngineError {
  auth,
  network,
  decode,
  formatUnsupported,
  generic,
}

/// One payload of an engine-side error event.  Engines emit these onto
/// [PlayerEngine.errorStream] so the cubit can mark a stream as failed
/// and drive its fallback / failure-state flow without parsing native
/// strings.
class EngineErrorEvent {
  const EngineErrorEvent({
    required this.type,
    this.message,
    this.cause,
  });

  /// Structured category — drives the cubit's branch logic.
  final EngineError type;

  /// Human-readable detail from the engine.  May be null when the
  /// engine has nothing better than the category itself; cubit logs
  /// this verbatim for post-hoc debugging.
  final String? message;

  /// The original error object from the engine (e.g. a libmpv error
  /// payload, an ExoPlayer `PlaybackException`).  Preserved so the
  /// cubit can inspect it for diagnostic logging without the engine
  /// needing to know what fields the cubit will look at.
  final Object? cause;

  @override
  String toString() =>
      'EngineErrorEvent(type=$type, message=$message, cause=$cause)';
}
