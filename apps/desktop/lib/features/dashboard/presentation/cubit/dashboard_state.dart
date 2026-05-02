import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/server_info.dart';

sealed class DashboardState {
  const DashboardState();
}

class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

class DashboardLoaded extends DashboardState {
  const DashboardLoaded({
    required this.serverInfo,
    required this.clients,
    this.libraryCount = 0,
  });

  final ServerInfo serverInfo;
  final List<ClientListItem> clients;
  final int libraryCount;

  int get pendingCount =>
      clients.where((c) => c.status == ClientStatus.pending).length;

  int get approvedCount =>
      clients.where((c) => c.status == ClientStatus.approved).length;
}

class DashboardFailure extends DashboardState {
  const DashboardFailure(this.message);

  final String message;
}
