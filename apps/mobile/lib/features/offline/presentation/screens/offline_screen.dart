/// Offline empty state — "You're offline" / "Retry connection" CTA.
///
/// Plan: [`docs/11_design/mobile_redesign_plan.md`](../../../../../../../docs/11_design/mobile_redesign_plan.md)
/// §M10 + §14 Offline · prototype source
/// `docs/11_design/prototype/app/mobile/screens/extras.jsx`
/// `EmptyOfflineScreen`.
///
/// **v1 status:** UI shell only.  No live connectivity detector wired —
/// the `connectivity_plus` package is not yet in `pubspec.yaml` and the
/// router has no "ping → push /offline" hook.  The route exists at
/// `Routes.offline` so v1.1 can plug in a `connectivity_plus` listener
/// or an `ApiClient.unauthorizedStream`-style "no-network" stream
/// without touching the screen itself.
///
/// **v1 button surface:** the prototype carries a secondary "Open
/// downloads" button alongside "Retry connection".  Downloads tab is
/// hidden in v1 (see real-data backfill plan §5 row 4 — `downloads_
/// screen.dart` stays in tree but the tab + route are gone), so the
/// "Open downloads" button is also hidden here.  Restore it alongside
/// the Downloads tab in v1.1 / Phase E by wiring the `onOpenDownloads`
/// callback path below.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';

class OfflineScreen extends StatelessWidget {
  const OfflineScreen({
    super.key,
    this.serverName,
    this.onRetry,
  });

  /// Optional server name to render in the body copy ("We can't reach
  /// **<serverName>** right now").  When null falls back to a generic
  /// "your server" — happens when the screen is reached without a
  /// stored server identity (pre-pair / sign-out states).
  final String? serverName;

  /// Override for the primary "Retry connection" button.  When null
  /// the default path pops back to the previous route if possible,
  /// else routes to `/home` so the router's auth-gate redirect can
  /// land the user wherever's appropriate (`/home` if authed,
  /// `/connect` if not).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _OfflineGlyph(),
                const SizedBox(height: 22),
                Text(
                  "You're offline",
                  style: AppTypography.displayV2.copyWith(
                    color: AppColors.textBright,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: Text.rich(
                    TextSpan(
                      style: AppTypography.body.copyWith(
                        color: AppColors.textMutedV2,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: "We can't reach "),
                        TextSpan(
                          text: serverName ?? 'your server',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textBright,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' right now.  Check the network and try again.',
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 22),
                FluxButton(
                  icon: LucideIcons.refreshCw,
                  onPressed: () => _onRetry(context),
                  child: const Text('Retry connection'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onRetry(BuildContext context) {
    if (onRetry != null) {
      onRetry!();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.home);
    }
  }
}

/// Centred 84-px violet-glow circle with a `wifi-off` Lucide icon.
class _OfflineGlyph extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: AppColors.violet.withValues(alpha: 0.10),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.wifiOff,
        size: 36,
        color: AppColors.violet,
      ),
    );
  }
}
