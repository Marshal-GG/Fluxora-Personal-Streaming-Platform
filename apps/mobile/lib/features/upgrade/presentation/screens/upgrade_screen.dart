import 'package:flutter/material.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';

/// Shown when the user hits a tier limit (PlayerTierLimit state / 429 response).
///
/// Explains the subscription tiers, current limits, and instructs the user to
/// activate a license key via the Fluxora Desktop Control Panel.
class UpgradeScreen extends StatelessWidget {
  const UpgradeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Upgrade Your Plan'),
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _GradientHeader(),
              const SizedBox(height: 32),

              // Tier cards
              ..._kTiers.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _TierCard(tier: t),
                  )),
              const SizedBox(height: 24),

              // How to activate
              _ActivationInstructions(),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _GradientHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.white, size: 48),
          const SizedBox(height: 12),
          Text(
            'Unlock More Streams',
            style: AppTypography.headingLg.copyWith(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve reached your plan\'s concurrent stream limit.\n'
            'Upgrade to stream to more devices simultaneously.',
            style: AppTypography.bodyMd.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tier data
// ─────────────────────────────────────────────────────────────────────────────

class _TierData {
  const _TierData({
    required this.name,
    required this.price,
    required this.streams,
    required this.features,
    required this.color,
    this.isPopular = false,
  });
  final String name;
  final String price;
  final String streams;
  final List<String> features;
  final Color color;
  final bool isPopular;
}

const _kTiers = [
  _TierData(
    name: 'Free',
    price: '\$0',
    streams: '1 concurrent stream',
    features: ['File browser', 'Basic HLS streaming', 'LAN only'],
    color: AppColors.textMuted,
  ),
  _TierData(
    name: 'Plus',
    price: '\$4.99 / mo',
    streams: '3 concurrent streams',
    features: [
      'Everything in Free',
      'TMDB metadata & posters',
      'Playback resume',
      'Internet streaming (WebRTC)',
    ],
    color: AppColors.info,
    isPopular: true,
  ),
  _TierData(
    name: 'Pro',
    price: '\$9.99 / mo',
    streams: '10 concurrent streams',
    features: [
      'Everything in Plus',
      'Hardware transcoding (NVENC/VAAPI)',
      'Priority support',
    ],
    color: AppColors.primary,
  ),
  _TierData(
    name: 'Ultimate',
    price: '\$19.99 / mo',
    streams: 'Unlimited streams',
    features: [
      'Everything in Pro',
      'AI file organisation',
      'Family sharing',
    ],
    color: AppColors.accentPurple,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Tier card
// ─────────────────────────────────────────────────────────────────────────────

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier});
  final _TierData tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: tier.isPopular ? tier.color : AppColors.surfaceRaised,
          width: tier.isPopular ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: tier.color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Text(
                  tier.name,
                  style: AppTypography.headingMd.copyWith(color: tier.color),
                ),
                if (tier.isPopular) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: tier.color,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      'POPULAR',
                      style: AppTypography.label.copyWith(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      tier.price,
                      style: AppTypography.headingMd
                          .copyWith(color: AppColors.textPrimary),
                    ),
                    Text(
                      tier.streams,
                      style: AppTypography.label
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Feature list
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: tier.features
                  .map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline,
                                size: 16, color: tier.color),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f,
                                style: AppTypography.bodySm.copyWith(
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activation instructions
// ─────────────────────────────────────────────────────────────────────────────

class _ActivationInstructions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.surfaceRaised),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'How to Activate',
                style: AppTypography.headingMd
                    .copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._kSteps.asMap().entries.map((e) => _Step(
                number: e.key + 1,
                text: e.value,
              )),
        ],
      ),
    );
  }
}

const _kSteps = [
  'Purchase a plan at fluxora.app (or request a license key from the server owner).',
  'Open the Fluxora Desktop Control Panel on the PC running your server.',
  'Go to Settings → enter your license key and tap Save.',
  'Your new tier activates immediately — no server restart required.',
];

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: AppTypography.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style:
                    AppTypography.bodySm.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
