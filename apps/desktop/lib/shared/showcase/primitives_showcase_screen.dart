/// Primitives showcase — visual diff harness for the redesign tokens.
///
/// Renders every redesign primitive in every variant on the redesign's
/// `bgRoot` background so you can side-by-side compare against the
/// prototype at `docs/11_design/desktop_prototype/Fluxora Desktop.html`.
///
/// Routed at `/showcase`. Not linked from the sidebar — open via deep link
/// during M1 review. Removed at the M9 cutover.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_progress.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/pill.dart';
import 'package:fluxora_desktop/shared/widgets/section_label.dart';
import 'package:fluxora_desktop/shared/widgets/sparkline.dart';
import 'package:fluxora_desktop/shared/widgets/stat_tile.dart';
import 'package:fluxora_desktop/shared/widgets/status_dot.dart';
import 'package:fluxora_desktop/shared/widgets/storage_donut.dart';

class PrimitivesShowcaseScreen extends StatelessWidget {
  const PrimitivesShowcaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.bgRoot,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.s28,
            vertical: AppSpacing.s24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Primitives Showcase',
                subtitle: 'Visual diff harness for the M1 design tokens',
              ),
              _LogoSection(),
              SizedBox(height: AppSpacing.s32),
              _CardSection(),
              SizedBox(height: AppSpacing.s32),
              _StatusDotSection(),
              SizedBox(height: AppSpacing.s32),
              _PillSection(),
              SizedBox(height: AppSpacing.s32),
              _ButtonSection(),
              SizedBox(height: AppSpacing.s32),
              _ProgressSection(),
              SizedBox(height: AppSpacing.s32),
              _StatTileSection(),
              SizedBox(height: AppSpacing.s32),
              _SparklineSection(),
              SizedBox(height: AppSpacing.s32),
              _DonutSection(),
              SizedBox(height: AppSpacing.s32),
              _TypographySection(),
              SizedBox(height: AppSpacing.s32),
              _SvgVisualsSection(),
              SizedBox(height: AppSpacing.s32),
              _EmptyStateSection(),
              SizedBox(height: AppSpacing.s32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section helpers ─────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionLabel(label),
        child,
      ],
    );
  }
}

// ── Logo section ───────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  const _LogoSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      label: 'LOGO',
      child: FluxCard(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FluxoraMark(size: 48),
            SizedBox(width: AppSpacing.s24),
            FluxoraMark(size: 48, glow: true),
            SizedBox(width: AppSpacing.s24),
            FluxoraWordmark(height: 28),
            SizedBox(width: AppSpacing.s24),
            FluxoraLogo(size: 32, withTagline: true),
          ],
        ),
      ),
    );
  }
}

// ── Card section ───────────────────────────────────────────────────────────

class _CardSection extends StatelessWidget {
  const _CardSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      label: 'CARD',
      child: Row(
        children: [
          Expanded(
            child: FluxCard(
              child: Text('Default', style: AppTypography.body),
            ),
          ),
          SizedBox(width: AppSpacing.s14),
          Expanded(
            child: FluxCard(
              hoverable: true,
              child: Text('Hoverable (mouse over)', style: AppTypography.body),
            ),
          ),
          SizedBox(width: AppSpacing.s14),
          Expanded(
            child: FluxCard(
              glow: true,
              child: Text('Glow', style: AppTypography.body),
            ),
          ),
        ],
      ),
    );
  }
}

// ── StatusDot section ──────────────────────────────────────────────────────

class _StatusDotSection extends StatelessWidget {
  const _StatusDotSection();

  @override
  Widget build(BuildContext context) {
    const statuses = DotStatus.values;
    return _Section(
      label: 'STATUS DOT',
      child: FluxCard(
        child: Wrap(
          spacing: AppSpacing.s24,
          runSpacing: AppSpacing.s12,
          children: [
            for (final s in statuses)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusDot(status: s),
                  const SizedBox(width: AppSpacing.s8),
                  Text(
                    s.name,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textBody,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ── Pill section ───────────────────────────────────────────────────────────

class _PillSection extends StatelessWidget {
  const _PillSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'PILL',
      child: FluxCard(
        child: Wrap(
          spacing: AppSpacing.s10,
          runSpacing: AppSpacing.s10,
          children: [
            for (final c in PillColor.values) Pill(c.name, color: c),
            const Pill('with icon', color: PillColor.purple, icon: Icons.bolt),
          ],
        ),
      ),
    );
  }
}

// ── Button section ─────────────────────────────────────────────────────────

class _ButtonSection extends StatelessWidget {
  const _ButtonSection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'BUTTON',
      child: FluxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final size in FluxButtonSize.values) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s8),
                child: Text(
                  'size: ${size.name}',
                  style: AppTypography.eyebrow,
                ),
              ),
              Wrap(
                spacing: AppSpacing.s10,
                runSpacing: AppSpacing.s10,
                children: [
                  for (final v in FluxButtonVariant.values)
                    FluxButton(
                      variant: v,
                      size: size,
                      icon: v == FluxButtonVariant.primary ? Icons.bolt : null,
                      onPressed: () {},
                      child: Text(v.name),
                    ),
                  // Disabled example for the size.
                  FluxButton(
                    variant: FluxButtonVariant.secondary,
                    size: size,
                    onPressed: null,
                    child: const Text('disabled'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.s16),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Progress section ───────────────────────────────────────────────────────

class _ProgressSection extends StatelessWidget {
  const _ProgressSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      label: 'PROGRESS',
      child: FluxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ProgressRow(label: '25%', value: 0.25),
            SizedBox(height: AppSpacing.s12),
            _ProgressRow(label: '50%', value: 0.50),
            SizedBox(height: AppSpacing.s12),
            _ProgressRow(label: '68%', value: 0.68),
            SizedBox(height: AppSpacing.s12),
            _ProgressRow(label: '100%', value: 1.0),
          ],
        ),
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          child: Text(
            label,
            style: AppTypography.monoCaption.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
        ),
        Expanded(child: FluxProgress(value: value)),
      ],
    );
  }
}

// ── StatTile section ───────────────────────────────────────────────────────

class _StatTileSection extends StatelessWidget {
  const _StatTileSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      label: 'STAT TILE',
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              icon: Icons.folder_outlined,
              label: 'Libraries',
              value: '4',
              color: AppColors.violet,
            ),
          ),
          SizedBox(width: AppSpacing.s14),
          Expanded(
            child: StatTile(
              icon: Icons.devices,
              label: 'Connected Clients',
              value: '2',
              color: AppColors.blue,
            ),
          ),
          SizedBox(width: AppSpacing.s14),
          Expanded(
            child: StatTile(
              icon: Icons.play_arrow,
              label: 'Active Streams',
              value: '1',
              color: AppColors.pink,
            ),
          ),
          SizedBox(width: AppSpacing.s14),
          Expanded(
            child: StatTile(
              icon: Icons.show_chart,
              label: 'CPU Usage',
              value: '18%',
              color: AppColors.amber,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sparkline section ──────────────────────────────────────────────────────

class _SparklineSection extends StatelessWidget {
  const _SparklineSection();

  @override
  Widget build(BuildContext context) {
    const data = <double>[
      18, 22, 19, 21, 24, 28, 26, 30, 27, 25, 23, 26, 29, 31, 28, 32, 35, 33,
      30, 28, 27, 29, 26, 24, 22, 25, 28, 31, 29, 27,
    ];
    return const _Section(
      label: 'SPARKLINE',
      child: FluxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Sparkline(data: data, color: AppColors.amber),
            SizedBox(height: AppSpacing.s14),
            Sparkline(data: data, color: AppColors.violet),
            SizedBox(height: AppSpacing.s14),
            Sparkline(data: data, color: AppColors.emerald),
          ],
        ),
      ),
    );
  }
}

// ── Donut section ──────────────────────────────────────────────────────────

class _DonutSection extends StatelessWidget {
  const _DonutSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      label: 'STORAGE DONUT',
      child: FluxCard(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            StorageDonut(
              segments: [
                StorageDonutSegment(percent: 46, color: AppColors.violet),
                StorageDonutSegment(percent: 32, color: AppColors.amber),
                StorageDonutSegment(percent: 12, color: AppColors.emerald),
                StorageDonutSegment(percent: 10, color: AppColors.pink),
              ],
              centerText: '2.72',
              unitText: 'TB',
            ),
            SizedBox(width: AppSpacing.s24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DonutLegendRow(label: 'Movies', size: '1.25 TB', pct: '46%', color: AppColors.violet),
                  _DonutLegendRow(label: 'TV Shows', size: '890 GB', pct: '32%', color: AppColors.amber),
                  _DonutLegendRow(label: 'Music', size: '320 GB', pct: '12%', color: AppColors.emerald),
                  _DonutLegendRow(label: 'Other', size: '260 GB', pct: '10%', color: AppColors.pink),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DonutLegendRow extends StatelessWidget {
  const _DonutLegendRow({
    required this.label,
    required this.size,
    required this.pct,
    required this.color,
  });

  final String label;
  final String size;
  final String pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(color: AppColors.textBody),
            ),
          ),
          Text(
            size,
            style: AppTypography.monoCaption.copyWith(color: AppColors.textMutedV2),
          ),
          const SizedBox(width: AppSpacing.s8),
          SizedBox(
            width: 36,
            child: Text(
              pct,
              textAlign: TextAlign.right,
              style: AppTypography.monoCaption.copyWith(color: AppColors.textDim),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Typography section ─────────────────────────────────────────────────────

class _TypographySection extends StatelessWidget {
  const _TypographySection();

  @override
  Widget build(BuildContext context) {
    return _Section(
      label: 'TYPOGRAPHY',
      child: FluxCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('displayV2 — 24/700/-0.01em', style: AppTypography.displayV2),
            const SizedBox(height: AppSpacing.s8),
            const Text('h1 — 18/700', style: AppTypography.h1),
            const SizedBox(height: AppSpacing.s8),
            const Text('h2 — 14/600', style: AppTypography.h2),
            const SizedBox(height: AppSpacing.s8),
            const Text('body — 13/500', style: AppTypography.body),
            const SizedBox(height: AppSpacing.s8),
            const Text('bodySmall — 12/500', style: AppTypography.bodySmall),
            const SizedBox(height: AppSpacing.s8),
            const Text('captionV2 — 11/500', style: AppTypography.captionV2),
            const SizedBox(height: AppSpacing.s8),
            const Text('micro — 10.5/500', style: AppTypography.micro),
            const SizedBox(height: AppSpacing.s8),
            const Text('eyebrow — 11/600/0.14em', style: AppTypography.eyebrow),
            const SizedBox(height: AppSpacing.s14),
            Text(
              '192.168.1.105',
              style: AppTypography.monoBody.copyWith(color: AppColors.textBody),
            ),
            const Text('h264_nvenc · 60 fps', style: AppTypography.monoCaption),
            const Text('2026-05-01 15:42:27.891', style: AppTypography.monoMicro),
          ],
        ),
      ),
    );
  }
}

// ── SVG visuals section (animated) ─────────────────────────────────────────

class _SvgVisualsSection extends StatelessWidget {
  const _SvgVisualsSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      label: 'ANIMATED SVG VISUALS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero waves — full-width decorative band.
          FluxCard(
            padding: 0,
            child: SizedBox(
              height: 140,
              child: ClipRRect(
                borderRadius: BorderRadius.all(Radius.circular(AppRadii.lg)),
                child: HeroWaves(),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.s14),
          // Brand loader + Pulse ring side by side
          Row(
            children: [
              Expanded(
                child: FluxCard(
                  child: Column(
                    children: [
                      BrandLoader(size: 64),
                      SizedBox(height: AppSpacing.s12),
                      Text(
                        'BrandLoader (PNG + ring)',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.s14),
              Expanded(
                child: FluxCard(
                  child: Column(
                    children: [
                      _PulseRingDemo(),
                      SizedBox(height: AppSpacing.s12),
                      Text(
                        'PulseRing (live status)',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.s14),
              Expanded(
                child: FluxCard(
                  child: Column(
                    children: [
                      _PulseRingDemo(color: AppColors.statusActive, size: 56),
                      SizedBox(height: AppSpacing.s12),
                      Text(
                        'PulseRing (online)',
                        style: AppTypography.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PulseRingDemo extends StatelessWidget {
  const _PulseRingDemo({this.color = AppColors.statusStreaming, this.size = 56});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: PulseRing(size: size, color: color),
    );
  }
}

// ── Empty-state section ────────────────────────────────────────────────────

class _EmptyStateSection extends StatelessWidget {
  const _EmptyStateSection();

  @override
  Widget build(BuildContext context) {
    return const _Section(
      label: 'EMPTY STATES',
      child: Row(
        children: [
          Expanded(
            child: FluxCard(
              padding: 28,
              child: EmptyState(
                illustration: EmptyStateIllustration.libraries,
                title: 'No libraries yet',
                message:
                    'Add a folder of movies, TV shows, or music to start streaming.',
              ),
            ),
          ),
          SizedBox(width: AppSpacing.s14),
          Expanded(
            child: FluxCard(
              padding: 28,
              child: EmptyState(
                illustration: EmptyStateIllustration.clients,
                title: 'No clients connected',
                message:
                    'Open the Fluxora app on a phone or laptop on the same network to pair.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
