/// Server picker — discovers Fluxora servers on the local network.
///
/// Mobile redesign plan §M12.
///
/// Surfaces:
///   • [_SearchingView]   — animated [BrandLoader] over the V2 backdrop.
///   • [_ServerListView]  — discovered servers as glass tiles.
///   • [_ErrorView]       — empty / failure state with a Retry CTA.
///
/// CTAs (always pinned to the bottom):
///   • Scan a QR code     → [Routes.scanQr]
///   • Enter manually     → [_ManualEntrySheet] via [showFluxBottomSheet]
///
/// The Reconnect (lost-token recovery) flow lives at [Routes.reconnect]
/// and is not surfaced from here.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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

class _ConnectView extends StatelessWidget {
  const _ConnectView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: FluxAppBar(
        title: 'Find your server',
        transparent: true,
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.splash),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Header(),
              const SizedBox(height: 24),
              Expanded(
                child: BlocBuilder<ConnectCubit, ConnectState>(
                  builder: (context, state) => _buildBody(context, state),
                ),
              ),
              const SizedBox(height: 12),
              const _BottomCtas(),
            ],
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
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Looking for Fluxora',
          style: AppTypography.eyebrow.copyWith(color: AppColors.violetTint),
        ),
        const SizedBox(height: 4),
        Text(
          'Pick your server',
          style: AppTypography.h1
              .copyWith(color: AppColors.textBright, fontSize: 22),
        ),
        const SizedBox(height: 6),
        Text(
          'Servers broadcasting on this network appear here. If yours '
          'doesn\'t show up, scan a QR code or enter the address manually.',
          style: AppTypography.body.copyWith(color: AppColors.textBody),
        ),
      ],
    );
  }
}

class _SearchingView extends StatelessWidget {
  const _SearchingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandLoader(size: 64),
          const SizedBox(height: 18),
          Text(
            'Scanning your network…',
            style: AppTypography.body.copyWith(color: AppColors.textBright),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'This usually takes a couple of seconds.',
            style: AppTypography.captionV2
                .copyWith(color: AppColors.textMutedV2),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            servers.length == 1
                ? '1 server found'
                : '${servers.length} servers found',
            style: AppTypography.eyebrow.copyWith(color: AppColors.textMutedV2),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: servers.length,
            padding: EdgeInsets.zero,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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
    return Semantics(
      button: true,
      label: 'Connect to ${server.name} at ${server.ip} port ${server.port}',
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _connect(context, server),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    LucideIcons.server,
                    color: AppColors.violetTint,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: AppTypography.h2.copyWith(
                          color: AppColors.textBright,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${server.ip}:${server.port}',
                        style: AppTypography.captionV2
                            .copyWith(color: AppColors.textMutedV2),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textDim,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
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
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.10),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Icon(
              LucideIcons.wifiOff,
              color: AppColors.violetTint,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Nothing on this network',
            style: AppTypography.h1
                .copyWith(color: AppColors.textBright, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              style: AppTypography.body.copyWith(color: AppColors.textBody),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 18),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            icon: Icons.refresh_rounded,
            onPressed: onRetry,
            child: const Text('Scan again'),
          ),
        ],
      ),
    );
  }
}

class _BottomCtas extends StatelessWidget {
  const _BottomCtas();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluxButton(
          fullWidth: true,
          size: FluxButtonSize.lg,
          icon: LucideIcons.qrCode,
          onPressed: () => context.push(Routes.scanQr),
          child: const Text('Scan a QR code'),
        ),
        const SizedBox(height: 10),
        FluxButton(
          fullWidth: true,
          size: FluxButtonSize.lg,
          variant: FluxButtonVariant.secondary,
          icon: LucideIcons.keyboard,
          onPressed: () => _openManualEntry(context),
          child: const Text('Enter address manually'),
        ),
      ],
    );
  }

  void _openManualEntry(BuildContext context) {
    showFluxBottomSheet<void>(
      context: context,
      builder: (_) => FluxBottomSheet(
        title: 'Manual connection',
        trailing: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppColors.textMutedV2),
          onPressed: () => Navigator.of(context).maybePop(),
          splashRadius: 18,
          tooltip: 'Close',
        ),
        child: _ManualEntryForm(
          onSubmit: (server) {
            Navigator.of(context).pop();
            _connect(context, server);
          },
        ),
      ),
    );
  }
}

class _ManualEntryForm extends StatefulWidget {
  const _ManualEntryForm({required this.onSubmit});

  final ValueChanged<DiscoveredServer> onSubmit;

  @override
  State<_ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<_ManualEntryForm> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '8000');
  String? _error;

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _submit() {
    final ip = _ipController.text.trim();
    // The `?? 8000` fallback is enforced by `tests/test_port_consistency.py`
    // — it must remain a literal so the lockstep guard catches drift across
    // the 5 files that hardcode the canonical port.  An empty/invalid port
    // input falls back to the canonical default; out-of-range values still
    // surface the inline validation error below.
    final port = int.tryParse(_portController.text.trim()) ?? 8000;
    if (ip.isEmpty) {
      setState(() => _error = 'Enter the server IP or hostname.');
      return;
    }
    if (port <= 0 || port > 65535) {
      setState(() => _error = 'Port must be between 1 and 65535.');
      return;
    }
    setState(() => _error = null);
    widget.onSubmit(DiscoveredServer(name: ip, ip: ip, port: port));
  }

  @override
  Widget build(BuildContext context) {
    // M14 polish: ordered focus traversal — IP -> Port -> Connect.
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Type the server\'s LAN address shown in the desktop control '
          'panel → Settings → Server.',
          style:
              AppTypography.captionV2.copyWith(color: AppColors.textMutedV2),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: FluxTextField(
                controller: _ipController,
                hint: '192.168.1.100',
                leadingIcon: LucideIcons.globe,
                keyboardType: TextInputType.url,
                onSubmitted: (_) => _submit(),
                autofocus: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FluxTextField(
                controller: _portController,
                hint: 'Port',
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _submit(),
              ),
            ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: AppTypography.captionV2
                .copyWith(color: const Color(0xFFF87171)),
          ),
        ],
        const SizedBox(height: 16),
        FluxButton(
          fullWidth: true,
          size: FluxButtonSize.lg,
          icon: Icons.arrow_forward_rounded,
          onPressed: _submit,
          child: const Text('Connect'),
        ),
        const SizedBox(height: 10),
      ],
      ),
    );
  }
}

void _connect(BuildContext context, DiscoveredServer server) {
  GetIt.I<ApiClient>().configure(localBaseUrl: server.url);
  context.go(Routes.pairing, extra: server);
}
