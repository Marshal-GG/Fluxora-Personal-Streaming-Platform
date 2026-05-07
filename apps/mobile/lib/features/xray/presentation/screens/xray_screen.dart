/// X-Ray panel — cast list + trivia / soundtrack cards over the player.
///
/// Plan: [`docs/11_design/mobile_redesign_plan.md`](../../../../../../../docs/11_design/mobile_redesign_plan.md)
/// §M10 + §14 X-Ray · prototype source
/// `docs/11_design/prototype/app/mobile/screens/extras.jsx` `XRayScreen`.
///
/// **v1 status:** UI shell only.  Decision §1 row 4 of the mobile
/// redesign plan keeps live ML / per-scene cast detection out of v1
/// scope — TMDB credits aren't wired yet (they're Phase C of the real-
/// data backfill plan), so this screen renders **static** mock cast +
/// placeholder trivia cards.  When TMDB credits + a real X-Ray source
/// land in v1.1, this screen swaps its body without touching the
/// route or entry-point wiring.
///
/// **Entry point:** small "X-Ray" chip on the player chrome's top bar
/// (`flux_player_controls.dart`) — pushes `Routes.xray` with the current
/// `MediaFile` as `extra`.  Screen falls back to a generic "X-Ray"
/// title when reached without an `extra`.
///
/// **Surface choice:** v1 ships as a regular pushed route over the
/// player, not a literal side-slide.  PlayerCubit is a `lazySingleton`
/// (M7) so dismissing this route pops back into the player without
/// restarting the stream.  M14 polish can convert to a horizontal-
/// slide overlay if the difference matters in motion.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:go_router/go_router.dart';

class XRayScreen extends StatelessWidget {
  const XRayScreen({super.key, this.file, this.title});

  /// Source file the user is watching when X-Ray is opened.  Drives
  /// the app-bar title and (in v1.1) will key the cast / trivia
  /// fetches.  Optional so the route can be deep-linked without
  /// state.
  final MediaFile? file;

  /// Title fallback for callers that don't have a `MediaFile` on hand
  /// (the player chrome only carries `fileName: String` in
  /// `PlayerReady`, not the full entity).  Ignored when `file` is set.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final displayTitle =
        file?.title ?? file?.name ?? title ?? 'X-Ray';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: FluxAppBar(
        title: 'X-Ray · $displayTitle',
        onBack: () =>
            context.canPop() ? context.pop() : context.go('/home'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          const _StaticOnlyNote(),
          const SizedBox(height: 18),
          const _Eyebrow('In this scene · 3'),
          const SizedBox(height: 6),
          ..._mockCast.map((c) => _CastRow(member: c)),
          const SizedBox(height: 24),
          const _Eyebrow('Trivia'),
          const SizedBox(height: 6),
          ..._mockTrivia.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TriviaCard(eyebrow: t.eyebrow, body: t.body),
              )),
        ],
      ),
    );
  }
}

// ── Static fixtures (v1 UI shell) ──────────────────────────────────────────

class _CastMember {
  const _CastMember({
    required this.name,
    required this.role,
    required this.initials,
    required this.gradient,
  });

  final String name;
  final String role;
  final String initials;
  final Gradient gradient;
}

class _Trivia {
  const _Trivia({required this.eyebrow, required this.body});
  final String eyebrow;
  final String body;
}

const _mockCast = <_CastMember>[
  _CastMember(
    name: 'Matthew McConaughey',
    role: 'as Cooper',
    initials: 'MM',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
  ),
  _CastMember(
    name: 'Anne Hathaway',
    role: 'as Brand',
    initials: 'AH',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ),
  ),
  _CastMember(
    name: 'David Gyasi',
    role: 'as Romilly',
    initials: 'DG',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
    ),
  ),
];

const _mockTrivia = <_Trivia>[
  _Trivia(
    eyebrow: 'Did you know?',
    body:
        'X-Ray surfaces cast, trivia, and soundtrack for the current scene.  '
        'Live scene detection lands in v1.1 — for now this is a static preview.',
  ),
  _Trivia(
    eyebrow: 'Soundtrack',
    body:
        'When TMDB credits + scene-time cues are wired (real-data backfill '
        'plan Phase C), this card will quote the playing track and link to '
        'the artist.',
  ),
];

// ── Widgets ────────────────────────────────────────────────────────────────

class _StaticOnlyNote extends StatelessWidget {
  const _StaticOnlyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x14A855F7),
        border: Border.all(color: const Color(0x40A855F7)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined,
              size: 16, color: AppColors.violetTint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Static preview — live scene detection ships in v1.1.',
              style: AppTypography.captionV2.copyWith(
                color: AppColors.violetTint,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.eyebrow.copyWith(
        color: AppColors.textDim,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _CastRow extends StatelessWidget {
  const _CastRow({required this.member});
  final _CastMember member;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: member.gradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              member.initials,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBright,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.role,
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textMutedV2,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textDim,
          ),
        ],
      ),
    );
  }
}

class _TriviaCard extends StatelessWidget {
  const _TriviaCard({required this.eyebrow, required this.body});
  final String eyebrow;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: AppTypography.captionV2.copyWith(
              color: AppColors.violet,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: AppTypography.body.copyWith(
              color: AppColors.textBody,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
