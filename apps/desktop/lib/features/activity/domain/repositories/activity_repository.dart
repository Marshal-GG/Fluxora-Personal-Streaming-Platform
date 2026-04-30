import 'package:fluxora_core/entities/stream_session.dart';

abstract class ActivityRepository {
  Future<List<StreamSession>> getActiveSessions();
  Future<void> stopSession(String sessionId);
}
