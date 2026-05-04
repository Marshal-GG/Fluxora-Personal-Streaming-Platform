import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/hardware_devices.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/transcoding/domain/repositories/transcoding_repository.dart';

/// One-shot hardware-detection cubit (server-side caches the probe; we
/// don't need to poll).  An explicit [refresh] lets the operator re-fetch
/// after they've, say, plugged in an eGPU and restarted the server.
sealed class HardwareState {
  const HardwareState();
}

final class HardwareInitial extends HardwareState {
  const HardwareInitial();
}

final class HardwareLoading extends HardwareState {
  const HardwareLoading();
}

final class HardwareLoaded extends HardwareState {
  const HardwareLoaded(this.devices);
  final HardwareDevices devices;
}

final class HardwareFailure extends HardwareState {
  const HardwareFailure(this.message);
  final String message;
}

class HardwareCubit extends Cubit<HardwareState> {
  HardwareCubit({required TranscodingRepository repository})
      : _repository = repository,
        super(const HardwareInitial());

  final TranscodingRepository _repository;
  static final _log = Logger();

  Future<void> load() async {
    if (isClosed) return;
    if (state is! HardwareLoaded) emit(const HardwareLoading());
    try {
      final devices = await _repository.devices();
      if (isClosed) return;
      emit(HardwareLoaded(devices));
    } catch (e, st) {
      _log.w('Hardware detection failed', error: e, stackTrace: st);
      if (isClosed) return;
      emit(HardwareFailure(e.toString()));
    }
  }

  Future<void> refresh() => load();
}
