import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_sizes.dart';
import 'package:fluxora_core/constants/app_typography.dart';
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
      )..startPairing(server),
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
        if (state is PairApproved) context.go(Routes.library);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.s6),
            child: BlocBuilder<PairCubit, PairState>(
              builder: (context, state) => _buildBody(context, state),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PairState state) {
    return switch (state) {
      PairInitial() || PairRequesting() => const _LoadingView(
          message: 'Connecting to server…',
        ),
      PairPending() => const _PendingView(),
      PairApproved() => const _LoadingView(
          message: 'Approved! Loading library…',
        ),
      PairRejected(:final reason) => _ErrorView(
          message: reason,
          actionLabel: 'Go back',
          onAction: () => Navigator.of(context).pop(),
        ),
      PairError(:final message) => _ErrorView(
          message: message,
          actionLabel: 'Try again',
          onAction: () => context.read<PairCubit>().startPairing(server),
        ),
    };
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSizes.s6),
          Text(
            message,
            style: AppTypography.bodyLg,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PendingView extends StatelessWidget {
  const _PendingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.s6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.devices_outlined,
              color: AppColors.primary,
              size: 48,
            ),
          ),
          const SizedBox(height: AppSizes.s6),
          const Text(
            'Waiting for approval',
            style: AppTypography.headingLg,
          ),
          const SizedBox(height: AppSizes.s3),
          const Text(
            'Open the Fluxora Control Panel on your\nserver and approve this device.',
            style: AppTypography.bodyMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.s6),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline,
            color: AppColors.error,
            size: 48,
          ),
          const SizedBox(height: AppSizes.s4),
          Text(
            message,
            style: AppTypography.bodyMd,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSizes.s6),
          ElevatedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
