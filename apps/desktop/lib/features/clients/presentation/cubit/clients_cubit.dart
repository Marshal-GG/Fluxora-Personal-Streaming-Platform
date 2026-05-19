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

  /// Re-fetch the client list without flickering through `ClientsLoading`.
  /// Intended for poll-driven refreshes (e.g. the Profile Sessions tab):
  /// preserves the existing `filter` + `processingIds` so the UI doesn't
  /// reset mid-revoke. No-op unless the cubit is already in
  /// [ClientsLoaded] — silent refresh has nothing to show against an
  /// initial / loading / failure state.
  Future<void> refreshSilent() async {
    final current = state;
    if (current is! ClientsLoaded) return;
    try {
      final clients = await _repository.getClients();
      final next = state;
      if (next is! ClientsLoaded) return;
      emit(next.copyWith(clients: clients));
    } catch (e, st) {
      // Preserve last-known state — don't surface error UI for poll noise.
      _log.w('Clients silent refresh failed', error: e, stackTrace: st);
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

  /// Revoke an already-approved client.  Calls `DELETE /auth/revoke/{id}`
  /// — kills the bearer immediately so any in-flight request from that
  /// device starts 401-ing on the next round-trip.  See
  /// [ClientsRepository.revokeClient] for the semantic difference vs
  /// [reject].
  Future<void> revoke(String clientId) async {
    final current = state;
    if (current is! ClientsLoaded) return;

    emit(current.copyWith(
      processingIds: {...current.processingIds, clientId},
    ));

    try {
      await _repository.revokeClient(clientId);
      await load();
    } on ApiException catch (e, st) {
      _log.e('Revoke failed for $clientId', error: e, stackTrace: st);
      final next = state;
      if (next is ClientsLoaded) {
        emit(next.copyWith(
          processingIds: {...next.processingIds}..remove(clientId),
        ));
      }
    } catch (e, st) {
      _log.e('Revoke failed for $clientId', error: e, stackTrace: st);
      final next = state;
      if (next is ClientsLoaded) {
        emit(next.copyWith(
          processingIds: {...next.processingIds}..remove(clientId),
        ));
      }
    }
  }

  /// Hard-delete a client row.  Calls `DELETE /auth/clients/{id}` —
  /// removes the `clients` row entirely (FKs cascade to
  /// `group_members`, null-out `stream_sessions.client_id`).  Use
  /// after a revoke when the operator wants to clean up the Revoked
  /// view.  Different from [revoke] which only flips the row to
  /// `status='rejected'`.
  Future<void> delete(String clientId) async {
    final current = state;
    if (current is! ClientsLoaded) return;

    emit(current.copyWith(
      processingIds: {...current.processingIds, clientId},
    ));

    try {
      await _repository.deleteClient(clientId);
      await load();
    } on ApiException catch (e, st) {
      _log.e('Delete failed for $clientId', error: e, stackTrace: st);
      final next = state;
      if (next is ClientsLoaded) {
        emit(next.copyWith(
          processingIds: {...next.processingIds}..remove(clientId),
        ));
      }
    } catch (e, st) {
      _log.e('Delete failed for $clientId', error: e, stackTrace: st);
      final next = state;
      if (next is ClientsLoaded) {
        emit(next.copyWith(
          processingIds: {...next.processingIds}..remove(clientId),
        ));
      }
    }
  }

  @override
  void emit(ClientsState state) {
    if (isClosed) return;
    super.emit(state);
  }
}
