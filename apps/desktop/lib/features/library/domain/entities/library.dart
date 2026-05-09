import 'package:equatable/equatable.dart';

/// Tri-state codec passthrough override for a single library — plan 19
/// §M8.  Mapping (UI ↔ API field):
///
///   - `null`  → "Use global setting" (inherit `user_settings`).
///   - `true`  → "Always" stream this codec directly to clients.
///   - `false` → "Never" stream-copy; always live-transcode this codec.
///
/// Stored on `libraries.{av1,vp9}_stream_copy_override` server-side.
/// The desktop holds it as a sidecar entity rather than extending the
/// core `Library` because the core Library entity is shared with
/// mobile + tests and doesn't need the field.
class LibraryCodecOverrides extends Equatable {
  const LibraryCodecOverrides({
    this.av1StreamCopyOverride,
    this.vp9StreamCopyOverride,
  });

  /// Per-library override for AV1 stream-copy.  See class doc.
  final bool? av1StreamCopyOverride;

  /// Per-library override for VP9 stream-copy.  See class doc.
  final bool? vp9StreamCopyOverride;

  /// Convenience for empty-state ("no overrides set").
  static const LibraryCodecOverrides empty = LibraryCodecOverrides();

  /// Read the two override fields off a server `Library` payload.
  /// Returns [empty] when neither field is present (older server build).
  factory LibraryCodecOverrides.fromJson(Map<String, dynamic> json) =>
      LibraryCodecOverrides(
        av1StreamCopyOverride: json['av1_stream_copy_override'] as bool?,
        vp9StreamCopyOverride: json['vp9_stream_copy_override'] as bool?,
      );

  LibraryCodecOverrides copyWith({
    bool? av1StreamCopyOverride,
    bool? vp9StreamCopyOverride,
    bool clearAv1 = false,
    bool clearVp9 = false,
  }) =>
      LibraryCodecOverrides(
        av1StreamCopyOverride: clearAv1
            ? null
            : (av1StreamCopyOverride ?? this.av1StreamCopyOverride),
        vp9StreamCopyOverride: clearVp9
            ? null
            : (vp9StreamCopyOverride ?? this.vp9StreamCopyOverride),
      );

  @override
  List<Object?> get props => [av1StreamCopyOverride, vp9StreamCopyOverride];
}
