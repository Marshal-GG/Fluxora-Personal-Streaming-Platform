import 'package:fluxora_core/entities/encoder_advice.dart';
import 'package:fluxora_core/entities/transcoding_status.dart';

sealed class TranscodingState {
  const TranscodingState();
}

final class TranscodingInitial extends TranscodingState {
  const TranscodingInitial();
}

final class TranscodingLoading extends TranscodingState {
  const TranscodingLoading();
}

final class TranscodingLoaded extends TranscodingState {
  const TranscodingLoaded(this.status, {this.advice});
  final TranscodingStatus status;

  /// Advisor recommendation for the active encoder.  Null while the advisor
  /// fetch is still in flight or has failed (advisor failure is non-fatal —
  /// the rest of the screen renders fine without it).
  final EncoderAdvice? advice;

  TranscodingLoaded copyWith({
    TranscodingStatus? status,
    EncoderAdvice? advice,
  }) =>
      TranscodingLoaded(
        status ?? this.status,
        advice: advice ?? this.advice,
      );
}

final class TranscodingFailure extends TranscodingState {
  const TranscodingFailure(this.message);
  final String message;
}
