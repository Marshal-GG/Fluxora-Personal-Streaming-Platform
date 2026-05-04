import 'package:fluxora_core/entities/encoder_advice.dart';
import 'package:fluxora_core/entities/fallback_event.dart';
import 'package:fluxora_core/entities/hardware_devices.dart';
import 'package:fluxora_core/entities/transcoding_status.dart';

abstract class TranscodingRepository {
  Future<TranscodingStatus> status();
  Future<EncoderAdvice> advisor();
  Future<HardwareDevices> devices();
  Future<FallbackHistory> fallbackHistory();
}
