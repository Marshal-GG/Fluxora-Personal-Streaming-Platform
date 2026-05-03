/// Reconnect screen — lost-token recovery.
///
/// Phase A backfill plan §9.2: when the bearer token is dead but the
/// device's `client_id` + `server_url` are still in secure storage
/// (e.g. operator revoked the client; another device re-paired with the
/// same `client_id` and invalidated this token; server's HMAC key was
/// rotated) the user lands here instead of being booted back through
/// full LAN discovery.
///
/// Behaviour:
///   1. On mount, [PairCubit.reconnect] reads `client_id` + `server_url`
///      from secure storage and re-fires `POST /auth/request-pair`.
///      The server's `auth_service.create_pair_request` resets the row
///      to `pending` (Phase A backfill plan §8.5 bug 1 fix), so the
///      operator just sees a fresh pairing request appear in the
///      desktop Clients screen.
///   2. The cubit polls `/auth/status/{client_id}`; on approval the new
///      token is saved over the old one and the user is routed to /home.
///   3. On `PairError` (no saved credentials, network error, etc.) the
///      surface offers "Sign out and pair again" → wipes secure storage
///      and routes to /connect.
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

class ReconnectScreen extends StatelessWidget {
  const ReconnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PairCubit>(
      create: (_) => PairCubit(
        repository: GetIt.I<AuthRepository>(),
        secureStorage: GetIt.I<SecureStorage>(),
      )..reconnect(),
      child: const _ReconnectView(),
    );
  }
}

class _ReconnectView extends StatelessWidget {
  const _ReconnectView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<PairCubit, PairState>(
      listener: (context, state) {
        if (state is PairApproved) context.go(Routes.home);
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: FluxAppBar(
          title: 'Reconnect',
          transparent: true,
          onBack: () =>
              context.canPop() ? context.pop() : context.go(Routes.connect),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: BlocBuilder<PairCubit, PairState>(
              builder: (context, state) => _StateBody(state: state),
            ),
          ),
        ),
      ),
    );
  }
}

class _StateBody extends StatelessWidget {
  const _StateBody({required this.state});

  final PairState state;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      PairInitial() ||
      PairRequesting() =>
        const _LoadingPanel(message: 'Reconnecting to your server…'),
      PairCollectEmail() => const _LoadingPanel(message: 'Reconnecting…'),
      PairPending() => const _PendingPanel(),
      PairApproved() => const _LoadingPanel(message: 'Approved — loading…'),
      PairRejected(:final reason) => _ErrorPanel(
          title: 'Reconnect rejected',
          message: reason,
          tint: const Color(0xFFFBBF24),
          icon: Icons.block_rounded,
        ),
      PairError(:final message) => _ErrorPanel(
          title: 'Couldn\'t reconnect',
          message: message,
          tint: const Color(0xFFF87171),
          icon: Icons.error_outline_rounded,
        ),
    };
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.violet,
            ),
          ),
          const SizedBox(height: 14),
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
  const _PendingPanel();

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
              Icons.refresh_rounded,
              color: AppColors.violet,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Waiting for re-approval',
            style: AppTypography.h1
                .copyWith(color: AppColors.textBright, fontSize: 20),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Your token expired or was revoked. Open the Fluxora '
              'desktop control panel and approve this device again — '
              'the previous session won\'t come back.',
              style: AppTypography.body.copyWith(color: AppColors.textBody),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 22),
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.violet,
            ),
          ),
          const SizedBox(height: 22),
          Builder(
            builder: (context) => FluxButton(
              variant: FluxButtonVariant.secondary,
              onPressed: () => _signOutAndConnect(context),
              child: const Text('Sign out and pair again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({
    required this.title,
    required this.message,
    required this.tint,
    required this.icon,
  });

  final String title;
  final String message;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
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
            onPressed: () => context.read<PairCubit>().reconnect(),
            child: const Text('Try again'),
          ),
          const SizedBox(height: 10),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            onPressed: () => _signOutAndConnect(context),
            child: const Text('Sign out and pair from scratch'),
          ),
        ],
      ),
    );
  }
}

Future<void> _signOutAndConnect(BuildContext context) async {
  final getIt = GetIt.I;
  getIt<ApiClient>().clearBearerToken();
  await getIt<SecureStorage>().deleteAll();
  if (!context.mounted) return;
  context.go(Routes.connect);
}
