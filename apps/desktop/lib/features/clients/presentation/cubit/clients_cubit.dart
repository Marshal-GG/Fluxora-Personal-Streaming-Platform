import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/network/api_exception.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/clients/domain/repositories/clients_repository.dart';
import 'package:fluxora_desktop/features/clients/presentation/cubit/clients_state.dart';

class ClientsCubit extends Cubit<ClientsState> {
  ClientsCubit({required ClientsRepository repository})
      : _repository = repository,
        super(const ClientsInitial());

  final ClientsRepository _repository;
  static final _log = Logger();

  Future<void> load() async {
    emit(const ClientsLoading());
    try {
      final clients = await _repository.getClients();
      emit(ClientsLoaded(clients: clients));
    } on ApiException catch (e, st) {
      _log.e('Clients load failed', error: e, stackTrace: st);
      emit(ClientsFailure(e.message));
    } catch (e, st) {
      _log.e('Clients load failed', error: e, stackTrace: st);
      emit(const ClientsFailure('Unable to reach server. Is it running?'));
    }
  }

  void setFilter(ClientStatus? filter) {
    final current = state;
    if (current is ClientsLoaded) {
      emit(current.copyWith(filter: filter));
    }
  }

  Future<void> approve(String clientId) async {
    final current = state;
    if (current is! ClientsLoaded) return;

    emit(current.copyWith(
      processingIds: {...current.processingIds, clientId},
    ));

    try {
      await _repository.approveClient(clientId);
      await load();
    } on ApiException catch (e, st) {
      _log.e('Approve failed for $clientId', error: e, stackTrace: st);
      final next = state;
      if (next is ClientsLoaded) {
        emit(next.copyWith(
          processingIds: {...next.processingIds}..remove(clientId),
        ));
      }
    } catch (e, st) {
      _log.e('Approve failed for $clientId', error: e, stackTrace: st);
      final next = state;
      if (next is ClientsLoaded) {
        emit(next.copyWith(
          processingIds: {...next.processingIds}..remove(clientId),
        ));
      }
    }
  }

  Future<void> reject(String clientId) async {
    final current = state;
    if (current is! ClientsLoaded) return;

    emit(current.copyWith(
      processingIds: {...current.processingIds, clientId},
    ));

    try {
      await _repository.rejectClient(clientId);
      await load();
    } on ApiException catch (e, st) {
      _log.e('Reject failed for $clientId', error: e, stackTrace: st);
      final next = state;
      if (next is ClientsLoaded) {
        emit(next.copyWith(
          processingIds: {...next.processingIds}..remove(clientId),
        ));
      }
    } catch (e, st) {
      _log.e('Reject failed for $clientId', error: e, stackTrace: st);
      final next = state;
      if (next is ClientsLoaded) {
        emit(next.copyWith(
          processingIds: {...next.processingIds}..remove(clientId),
        ));
      }
    }
  }
}
