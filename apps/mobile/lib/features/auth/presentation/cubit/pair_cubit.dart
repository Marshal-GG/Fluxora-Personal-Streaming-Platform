import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:fluxora_mobile/features/auth/presentation/cubit/pair_state.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';

/// Drives both the initial-pair and re-pair flows (Phase A backfill plan
/// §9.2 / §9.4 commit 3).
///
/// The cubit owns the pairing state machine; UI screens are pure render
/// surfaces.  See `pair_state.dart` for the state transitions.
class PairCubit extends Cubit<PairState> {
  PairCubit({
    required AuthRepository repository,
    SecureStorage? secureStorage,
    Duration pollInterval = const Duration(seconds: 3),
  })  : _repository = repository,
        _secureStorage = secureStorage,
        _pollInterval = pollInterval,
        super(const PairInitial());

  final AuthRepository _repository;
  final SecureStorage? _secureStorage;
  final Duration _pollInterval;
  static final _log = Logger();

  Timer? _pollTimer;
  String? _pendingClientId;
  String? _pendingServerUrl;

  /// Initial-pair entry: park on the email-collection step before sending
  /// the request.  The screen drives `submitEmail()` once the user taps
  /// either Continue or Skip.
  void prepare(DiscoveredServer server) {
    emit(PairCollectEmail(server: server));
  }

  /// Initial-pair: actually send the request-pair body.  Called by the
  /// pairing screen with whatever the user typed in the email field
  /// (`null` for "Skip").  Generates a fresh `client_id` UUID.
  Future<void> submitEmail({
    required DiscoveredServer server,
    String? email,
  }) async {
    _pendingServerUrl = server.url;
    _pendingClientId = _generateClientId();
    await _request(email: email);
  }

  /// Re-pair entry: pulls the previously-saved `client_id` + `server_url`
  /// out of secure storage and re-uses them.  The server's
  /// `auth_service.create_pair_request` resets the existing row to
  /// `pending` (Phase A backfill plan §8.5 bug 1), so once the operator
  /// approves the request again the new token replaces the dead one.
  ///
  /// If either credential is missing, the cubit emits [PairError] —
  /// callers should fall back to the full `/connect` flow.
  Future<void> reconnect() async {
    final storage = _secureStorage;
    if (storage == null) {
      emit(const PairError('Reconnect requires secure storage.'));
      return;
    }
    emit(const PairRequesting());
    try {
      final serverUrl = await storage.getServerUrl();
      final clientId = await storage.getClientId();
      if (serverUrl == null || clientId == null) {
        emit(const PairError(
          'No saved server to reconnect to. Pair from scratch instead.',
        ));
        return;
      }
      _pendingServerUrl = serverUrl;
      _pendingClientId = clientId;
      await _request(email: null);
    } on ApiException catch (e, st) {
      _log.e('reconnect read storage failed', error: e, stackTrace: st);
      emit(PairError(e.message));
    } catch (e, st) {
      _log.e('reconnect unexpected error', error: e, stackTrace: st);
      emit(const PairError('Could not reconnect to your server.'));
    }
  }

  Future<void> _request({String? email}) async {
    if (state is! PairRequesting) emit(const PairRequesting());
    try {
      await _repository.requestPair(
        clientId: _pendingClientId!,
        deviceName: _deviceName(),
        platform: _platformName(),
        appVersion: '0.1.0',
        email: email,
      );
      emit(const PairPending());
      _startPolling();
    } on ApiException catch (e, st) {
      _log.e('requestPair failed', error: e, stackTrace: st);
      emit(PairError(e.message));
    } catch (e, st) {
      _log.e('requestPair unexpected error', error: e, stackTrace: st);
      emit(const PairError('An unexpected error occurred.'));
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      _pollInterval,
      (_) async => _checkStatus(),
    );
  }

  Future<void> _checkStatus() async {
    final clientId = _pendingClientId;
    final serverUrl = _pendingServerUrl;
    if (clientId == null || serverUrl == null) return;

    try {
      final token = await _repository.pollStatus(clientId);
      if (token != null) {
        _pollTimer?.cancel();
        await _repository.saveCredentials(
          serverUrl: serverUrl,
          authToken: token,
          clientId: clientId,
        );
        emit(const PairApproved());
      }
    } on PairRejectedException {
      _pollTimer?.cancel();
      emit(const PairRejected('Your pairing request was rejected.'));
    } on ApiException catch (e, st) {
      _log.w('pollStatus error (will retry)', error: e, stackTrace: st);
    } catch (e, st) {
      _log.e('pollStatus unexpected error', error: e, stackTrace: st);
    }
  }

  @override
  Future<void> close() async {
    _pollTimer?.cancel();
    await super.close();
  }

  static String _generateClientId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  static String _deviceName() {
    if (Platform.isAndroid) return 'Android Device';
    if (Platform.isIOS) return 'iPhone';
    return 'Mobile Device';
  }

  static String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'mobile';
  }
}
