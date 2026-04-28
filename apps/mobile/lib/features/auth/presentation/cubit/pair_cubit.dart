import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:fluxora_mobile/features/auth/presentation/cubit/pair_state.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';

class PairCubit extends Cubit<PairState> {
  PairCubit({
    required AuthRepository repository,
    Duration pollInterval = const Duration(seconds: 3),
  })  : _repository = repository,
        _pollInterval = pollInterval,
        super(const PairInitial());

  final AuthRepository _repository;
  final Duration _pollInterval;
  static final _log = Logger();

  Timer? _pollTimer;
  String? _pendingClientId;
  String? _pendingServerUrl;

  Future<void> startPairing(DiscoveredServer server) async {
    emit(const PairRequesting());
    _pendingServerUrl = server.url;
    _pendingClientId = _generateClientId();

    try {
      await _repository.requestPair(
        clientId: _pendingClientId!,
        deviceName: _deviceName(),
        platform: _platformName(),
        appVersion: '0.1.0',
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
