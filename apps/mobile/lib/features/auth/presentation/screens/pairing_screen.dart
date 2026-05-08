/// Pairing screen — initial-pair flow only.
///
/// The Reconnect (lost-token recovery) flow lives at [Routes.reconnect]
/// and uses [ReconnectScreen] — see `reconnect_screen.dart`.
///
/// State-machine surfaces (Phase A backfill plan §9.2):
///   PairCollectEmail → optional email field + Continue / Skip buttons.
///   PairRequesting   → "Connecting…" spinner.
///   PairPending      → "Waiting for approval" panel with the device
///                      name + platform + a Cancel affordance.
///   PairApproved     → routes to /home via the BlocListener.
///   PairRejected     → red surface + "Try another server" button.
///   PairError        → red surface + "Try again" button.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/auth/domain/repositories/auth_repository.dart';
import 'package:fluxora_mobile/features/auth/presentation/cubit/pair_cubit.dart';
import 'package:fluxora_mobile/features/auth/presentation/cubit/pair_state.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';

class PairingScreen extends StatelessWidget {
  const PairingScreen({required this.server, super.key});

  final DiscoveredServer server;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PairCubit>(
      create: (_) => PairCubit(
        repository: GetIt.I<AuthRepository>(),
        secureStorage: GetIt.I<SecureStorage>(),
      )..prepare(server),
      child: _PairingView(server: server),
    );
  }
}

class _PairingView extends StatelessWidget {
  const _PairingView({required this.server});

  final DiscoveredServer server;

  @override
  Widget build(BuildContext context) {
    return BlocListener<PairCubit, PairState>(
      listener: (context, state) {
        if (state is PairApproved) context.go(Routes.home);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: FluxAppBar(
          title: 'Pair device',
          transparent: true,
          onBack: () =>
              context.canPop() ? context.pop() : context.go(Routes.connect),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: BlocBuilder<PairCubit, PairState>(
              builder: (context, state) =>
                  _StateBody(server: server, state: state),
            ),
          ),
        ),
      ),
    );
  }
}

class _StateBody extends StatelessWidget {
  const _StateBody({required this.server, required this.state});

  final DiscoveredServer server;
  final PairState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      PairInitial() => const _LoadingPanel(message: 'Preparing…'),
      PairCollectEmail() => _EmailEntryPanel(server: server),
      PairRequesting() =>
        const _LoadingPanel(message: 'Connecting to server…'),
      PairPending() => _PendingPanel(server: server),
      PairApproved() =>
        const _LoadingPanel(message: 'Approved! Loading library…'),
      PairRejected(:final reason) => _ErrorPanel(
          message: reason,
          actionLabel: 'Try another server',
          onAction: () => context.go(Routes.connect),
          variant: _ErrorPanelVariant.rejected,
        ),
      PairError(:final message) => _ErrorPanel(
          message: message,
          actionLabel: 'Try again',
          onAction: () => context.read<PairCubit>().prepare(server),
          variant: _ErrorPanelVariant.error,
        ),
    };
  }
}

// ── Email-entry panel (optional) ────────────────────────────────────────────

class _EmailEntryPanel extends StatefulWidget {
  const _EmailEntryPanel({required this.server});

  final DiscoveredServer server;

  @override
  State<_EmailEntryPanel> createState() => _EmailEntryPanelState();
}

class _EmailEntryPanelState extends State<_EmailEntryPanel> {
  final _controller = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit({required bool skip}) {
    final raw = _controller.text.trim();
    final email = skip || raw.isEmpty ? null : raw;
    if (email != null && !_looksLikeEmail(email)) {
      setState(
        () => _validationError = 'That doesn\'t look like an email address.',
      );
      return;
    }
    setState(() => _validationError = null);
    context.read<PairCubit>().submitEmail(
          server: widget.server,
          email: email,
        );
  }

  static bool _looksLikeEmail(String value) {
    // Matches the smallest sane "x@y.z" shape — server treats this field
    // as advisory (echoed back, never used as identity), so we only
    // reject obvious typos.
    final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return re.hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 24),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.violet.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: const Icon(
            Icons.devices_outlined,
            color: AppColors.violet,
            size: 28,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Pair with ${widget.server.name}',
          style: AppTypography.h1
              .copyWith(color: AppColors.textBright, fontSize: 20),
        ),
        const SizedBox(height: 6),
        Text(
          '${widget.server.ip}:${widget.server.port}',
          style: AppTypography.captionV2.copyWith(color: AppColors.textMutedV2),
        ),
        const SizedBox(height: 24),
        Text(
          'Email (optional)',
          style: AppTypography.eyebrow
              .copyWith(color: AppColors.textBody, letterSpacing: 0.4),
        ),
        const SizedBox(height: 8),
        FluxTextField(
          controller: _controller,
          hint: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
          onSubmitted: (_) => _submit(skip: false),
        ),
        const SizedBox(height: 6),
        if (_validationError != null)
          Text(
            _validationError!,
            style: AppTypography.captionV2
                .copyWith(color: const Color(0xFFF87171)),
          )
        else
          Text(
            'Shown to your server operator alongside this device. Skip '
            'if you don\'t want to share one.',
            style: AppTypography.captionV2
                .copyWith(color: AppColors.textMutedV2),
          ),
        const SizedBox(height: 28),
        FluxButton(
          icon: Icons.check_rounded,
          onPressed: () => _submit(skip: false),
          child: const Text('Continue'),
        ),
        const SizedBox(height: 10),
        FluxButton(
          variant: FluxButtonVariant.secondary,
          onPressed: () => _submit(skip: true),
          child: const Text('Skip'),
        ),
      ],
    );
  }
}

// ── Loading + Pending + Error panels ────────────────────────────────────────

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BrandLoader(size: 56),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.body.copyWith(color: AppColors.textBright),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PendingPanel extends StatelessWidget {
  const _PendingPanel({required this.server});

  final DiscoveredServer server;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.violet.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: const Icon(
              Icons.hourglass_top_rounded,
              color: AppColors.violet,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Waiting for approval',
            style: AppTypography.h1
                .copyWith(color: AppColors.textBright, fontSize: 20),
          ),
          const SizedBox(height: 6),
          Text(
            'Open the Fluxora desktop control panel on\n'
            '${server.name} (${server.ip}) and approve this device.',
            style: AppTypography.body.copyWith(color: AppColors.textBody),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 22),
          const BrandLoader(size: 32),
          const SizedBox(height: 22),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            onPressed: () => context.go(Routes.connect),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

enum _ErrorPanelVariant { rejected, error }

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.message,
    required this.actionLabel,
    required this.onAction,
    required this.variant,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final _ErrorPanelVariant variant;

  @override
  Widget build(BuildContext context) {
    final tint = variant == _ErrorPanelVariant.rejected
        ? const Color(0xFFFBBF24)
        : const Color(0xFFF87171);
    final icon = variant == _ErrorPanelVariant.rejected
        ? Icons.block_rounded
        : Icons.error_outline_rounded;
    final title = variant == _ErrorPanelVariant.rejected
        ? 'Pairing rejected'
        : 'Couldn\'t pair';

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: tint.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, color: tint, size: 40),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: AppTypography.h1
                .copyWith(color: AppColors.textBright, fontSize: 20),
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
          const SizedBox(height: 22),
          FluxButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
