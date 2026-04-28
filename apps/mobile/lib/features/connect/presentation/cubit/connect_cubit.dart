import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';
import 'package:fluxora_mobile/features/connect/domain/repositories/server_discovery_repository.dart';
import 'package:fluxora_mobile/features/connect/presentation/cubit/connect_state.dart';

const _multicastChannel = MethodChannel('dev.marshalx.fluxora/multicast');

class ConnectCubit extends Cubit<ConnectState> {
  ConnectCubit({required ServerDiscoveryRepository repository})
      : _repository = repository,
        super(const ConnectInitial());

  final ServerDiscoveryRepository _repository;
  static final _log = Logger();

  StreamSubscription<DiscoveredServer>? _discoverySubscription;
  final List<DiscoveredServer> _discovered = [];

  Future<void> startDiscovery() async {
    _discovered.clear();
    emit(const ConnectSearching());

    try {
      await _multicastChannel.invokeMethod<void>('acquire');
    } catch (e) {
      // Non-fatal — platform may not support the channel (e.g. iOS, desktop)
      _log.w('Could not acquire multicast lock', error: e);
    }

    _discoverySubscription?.cancel();
    _discoverySubscription = _repository.discoverViaMulticast().listen(
      (server) {
        if (!_discovered.any((s) => s.ip == server.ip)) {
          _discovered.add(server);
          emit(ConnectFound(List.unmodifiable(_discovered)));
        }
      },
      onError: (Object e, StackTrace st) {
        _log.e('Discovery stream error', error: e, stackTrace: st);
        if (state is ConnectSearching) {
          emit(const ConnectError('Discovery failed. Check your network.'));
        }
      },
      onDone: () {
        if (state is ConnectSearching) {
          emit(
            const ConnectError('No Fluxora servers found on this network.'),
          );
        }
      },
    );
  }

  void stopDiscovery() {
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    _multicastChannel.invokeMethod<void>('release').ignore();
  }

  @override
  Future<void> close() async {
    _discoverySubscription?.cancel();
    _multicastChannel.invokeMethod<void>('release').ignore();
    await super.close();
  }
}
