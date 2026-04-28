import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/entities/enums.dart';

sealed class ClientsState {
  const ClientsState();
}

class ClientsInitial extends ClientsState {
  const ClientsInitial();
}

class ClientsLoading extends ClientsState {
  const ClientsLoading();
}

class ClientsLoaded extends ClientsState {
  const ClientsLoaded({
    required this.clients,
    this.filter,
    this.processingIds = const {},
  });

  final List<ClientListItem> clients;

  /// null means show all
  final ClientStatus? filter;

  /// IDs of clients currently being approved / rejected
  final Set<String> processingIds;

  List<ClientListItem> get filtered => filter == null
      ? clients
      : clients.where((c) => c.status == filter).toList();

  ClientsLoaded copyWith({
    List<ClientListItem>? clients,
    Object? filter = _sentinel,
    Set<String>? processingIds,
  }) {
    return ClientsLoaded(
      clients: clients ?? this.clients,
      filter: filter == _sentinel
          ? this.filter
          : filter as ClientStatus?,
      processingIds: processingIds ?? this.processingIds,
    );
  }
}

const _sentinel = Object();

class ClientsFailure extends ClientsState {
  const ClientsFailure(this.message);

  final String message;
}
