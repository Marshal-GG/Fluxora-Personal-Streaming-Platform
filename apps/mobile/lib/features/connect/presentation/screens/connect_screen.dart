import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_sizes.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';
import 'package:fluxora_mobile/features/connect/domain/repositories/server_discovery_repository.dart';
import 'package:fluxora_mobile/features/connect/presentation/cubit/connect_cubit.dart';
import 'package:fluxora_mobile/features/connect/presentation/cubit/connect_state.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConnectCubit>(
      create: (_) => ConnectCubit(
        repository: GetIt.I<ServerDiscoveryRepository>(),
      )..startDiscovery(),
      child: const _ConnectView(),
    );
  }
}

class _ConnectView extends StatefulWidget {
  const _ConnectView();

  @override
  State<_ConnectView> createState() => _ConnectViewState();
}

class _ConnectViewState extends State<_ConnectView> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8080');
  bool _showManual = false;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.s6),
          child: BlocBuilder<ConnectCubit, ConnectState>(
            builder: (context, state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSizes.s8),
                const Text('Fluxora', style: AppTypography.displayMd),
                const SizedBox(height: AppSizes.s1),
                const Text(
                  'Connect to your server',
                  style: AppTypography.bodyLg,
                ),
                const SizedBox(height: AppSizes.s10),
                Expanded(child: _buildBody(context, state)),
                const SizedBox(height: AppSizes.s4),
                _showManual
                    ? _buildManualEntry(context)
                    : SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () =>
                              setState(() => _showManual = true),
                          child: const Text(
                            'Enter server address manually',
                          ),
                        ),
                      ),
                const SizedBox(height: AppSizes.s4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ConnectState state) {
    return switch (state) {
      ConnectInitial() || ConnectSearching() => const _SearchingView(),
      ConnectFound(:final servers) => _ServerListView(servers: servers),
      ConnectError(:final message) => _ErrorView(
          message: message,
          onRetry: () => context.read<ConnectCubit>().startDiscovery(),
        ),
    };
  }

  Widget _buildManualEntry(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Manual connection', style: AppTypography.headingMd),
        const SizedBox(height: AppSizes.s3),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _ipController,
                decoration: const InputDecoration(
                  labelText: 'IP address',
                  hintText: '192.168.1.100',
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: AppSizes.s2),
            Expanded(
              child: TextField(
                controller: _portController,
                decoration: const InputDecoration(labelText: 'Port'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.s3),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _connectManually(context),
            child: const Text('Connect'),
          ),
        ),
      ],
    );
  }

  void _connectManually(BuildContext context) {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 8080;
    if (ip.isEmpty) return;
    final server = DiscoveredServer(name: ip, ip: ip, port: port);
    GetIt.I<ApiClient>().configure(localBaseUrl: server.url);
    context.go(Routes.pairing, extra: server);
  }
}

class _SearchingView extends StatelessWidget {
  const _SearchingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: AppSizes.s4),
          Text(
            'Scanning your network for Fluxora servers…',
            style: AppTypography.bodyMd,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ServerListView extends StatelessWidget {
  const _ServerListView({required this.servers});

  final List<DiscoveredServer> servers;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Servers found', style: AppTypography.headingSm),
        const SizedBox(height: AppSizes.s3),
        Expanded(
          child: ListView.separated(
            itemCount: servers.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSizes.s2),
            itemBuilder: (context, index) =>
                _ServerTile(server: servers[index]),
          ),
        ),
      ],
    );
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({required this.server});

  final DiscoveredServer server;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        GetIt.I<ApiClient>().configure(localBaseUrl: server.url);
        context.go(Routes.pairing, extra: server);
      },
      child: Container(
        padding: const EdgeInsets.all(AppSizes.s4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusLg),
          border: Border.all(color: AppColors.surfaceRaised),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              ),
              child: const Icon(
                Icons.dns_outlined,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: AppSizes.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(server.name, style: AppTypography.headingMd),
                  Text(
                    '${server.ip}:${server.port}',
                    style: AppTypography.caption,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.wifi_off_outlined,
            color: AppColors.textMuted,
            size: 48,
          ),
          const SizedBox(height: AppSizes.s4),
          Text(
            message,
            style: AppTypography.bodyMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.s4),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
