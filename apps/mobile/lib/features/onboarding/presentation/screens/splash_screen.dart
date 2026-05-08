/// Splash screen — first surface on a fresh install.
///
/// Mobile redesign plan §M12 (`prototype/app/mobile/screens/splash.jsx`).
///
/// Fluxora has no credential auth — there is only operator-approval
/// pairing — so the prototype's three CTAs collapse into two real paths:
/// the primary CTA opens server discovery; the secondary opens the QR
/// scanner. The "Continue as guest" link from the prototype is dropped:
/// the app cannot operate without a paired server, and offering a path
/// that immediately leads back here would be UX clutter.
///
/// Auth-gate (router `_guardRedirect`) sends authenticated users
/// straight to `/home`, so this screen is only ever the first surface
/// on a fresh install or right after a sign-out cleared secure storage.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 28),
          child: Column(
            children: [
              const Expanded(child: _Hero()),
              _Ctas(
                onPrimary: () => context.go(Routes.connect),
                onSecondary: () => context.push(Routes.scanQr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const FluxoraMark(size: 104, glow: true),
          const SizedBox(height: 28),
          const FluxoraWordmark(height: 26),
          const SizedBox(height: 14),
          Text(
            'Stream. Sync. Anywhere.',
            style: AppTypography.body.copyWith(
              fontSize: 13,
              color: AppColors.textBody.withValues(alpha: 0.65),
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 28),
          const _PageDots(activeIndex: 0, count: 3),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.activeIndex, required this.count});

  final int activeIndex;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < count; i++) ...[
          Container(
            width: i == activeIndex ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color: i == activeIndex
                  ? AppColors.violet
                  : Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          if (i < count - 1) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _Ctas extends StatelessWidget {
  const _Ctas({required this.onPrimary, required this.onSecondary});

  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FluxButton(
          size: FluxButtonSize.lg,
          fullWidth: true,
          onPressed: onPrimary,
          child: const Text('Connect to a server'),
        ),
        const SizedBox(height: 10),
        FluxButton(
          size: FluxButtonSize.lg,
          fullWidth: true,
          variant: FluxButtonVariant.secondary,
          icon: LucideIcons.qrCode,
          onPressed: onSecondary,
          child: const Text('Scan a QR code'),
        ),
        const SizedBox(height: 16),
        Text(
          'By continuing you accept that pairing requires the operator '
          'of your Fluxora server to approve this device.',
          textAlign: TextAlign.center,
          style: AppTypography.captionV2.copyWith(
            fontSize: 11,
            color: AppColors.textDim,
          ),
        ),
      ],
    );
  }
}
