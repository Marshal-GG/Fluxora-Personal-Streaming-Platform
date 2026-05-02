import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/transcoding/domain/repositories/transcoding_repository.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/transcoding_state.dart';

/// Polls `GET /api/v1/transcoding/status` every 2 seconds.
///
/// Mirrors the pattern used by [SystemStatsCubit] — polling chosen over
/// WebSocket to keep infrastructure minimal for v1.
class TranscodingCubit extends Cubit<TranscodingState> {
  TranscodingCubit({required TranscodingRepository repository})
      : _repository = repository,
        super(const TranscodingInitial());

  final TranscodingRepository _repository;
  static final _log = Logger();
  Timer? _timer;

  static const Duration _interval = Duration(seconds: 2);

  /// Fetch once immediately, then start polling.
  void start() {
    if (_timer != null) return;
    _tick();
    _timer = Timer.periodic(_interval, (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() => _tick();

  Future<void> _tick() async {
    // Only emit loading on first load to avoid flicker during polls.
    if (state is TranscodingInitial) emit(const TranscodingLoading());
    try {
      final result = await _repository.status();
      emit(TranscodingLoaded(result));
    } catch (e, st) {
      _log.e('TranscodingCubit poll failed', error: e, stackTrace: st);
      // Only surface failure on first load; preserve last known state on
      // subsequent poll errors so the UI doesn't blank out.
      if (state is TranscodingInitial || state is TranscodingLoading) {
        emit(TranscodingFailure(e.toString()));
      }
    }
  }

  @override
  Future<void> close() {
    stop();
    return super.close();
  }
}
