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
  const TranscodingLoaded(this.status);
  final TranscodingStatus status;
}

final class TranscodingFailure extends TranscodingState {
  const TranscodingFailure(this.message);
  final String message;
}
