import 'package:fluxora_mobile/features/player/domain/entities/stream_start_response.dart';

abstract class PlayerRepository {
  Future<StreamStartResponse> startStream(String fileId);
  Future<void> stopStream(String sessionId);
}
