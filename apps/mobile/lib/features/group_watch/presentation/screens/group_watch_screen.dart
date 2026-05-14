/// Group Watch (party / co-watch) — UI shell only.
///
/// Plan: [`docs/11_design/mobile_redesign_plan.md`](../../../../../../../docs/11_design/mobile_redesign_plan.md)
/// §M10 + §14 Group Watch · prototype source
/// `docs/11_design/prototype/app/mobile/screens/extras.jsx`
/// `GroupWatchScreen`.
///
/// **v1 status:** UI shell only.  Decision §1 row 4 of the mobile
/// redesign plan keeps multi-client sync (everyone-within-1-second
/// playback alignment, chat, reactions) out of v1 scope — that needs a
/// signaling backend the server doesn't ship yet.  This screen renders
/// the prototype's chrome (hero card, in-the-room list, invite-link
/// card, Leave / Resume buttons) backed by static fixtures + a "Sync
/// engine in v1.1" banner so the user can see the surface but not
/// expect it to actually sync.
///
/// **Note on terminology:** "Group Watch" (this feature — multi-client
/// party-watch) is **not** the same as "Client Groups" / Groups v2 (the
/// access-control content-spaces in [`docs/10_planning/13_groups_v2_
/// content_spaces.md`](../../../../../../../docs/10_planning/13_groups_v2_content_spaces.md)).
/// Both terms exist in the codebase; don't conflate them.  Plan §1 row
/// 4 calls this out explicitly.
///
/// **Surface choice:** v1 ships as a regular pushed route over the
/// player.  PlayerCubit is a `lazySingleton` (M7) so dismissing this
/// route returns to the player without restarting the stream.  M14
/// polish can convert to a literal modal sheet if the difference
/// matters in motion.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:go_router/go_router.dart';

class GroupWatchScreen extends StatelessWidget {
  const GroupWatchScreen({super.key, this.title});

  /// Title of the source the user is watching when Group Watch is
  /// opened.  Drives the hero card subtitle.  Optional — falls back
  /// to a generic "this stream" so the screen still renders when
  /// reached without state.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final displayTitle = title ?? 'this stream';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: FluxAppBar(
        title: 'Group Watch',
        onBack: () =>
            context.canPop() ? context.pop() : context.go('/home'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const _ShellNote(),
          const SizedBox(height: 14),
          _HeroCard(title: displayTitle),
          const SizedBox(height: 18),
          const _Eyebrow('In the room · 4'),
          const SizedBox(height: 6),
          ..._mockRoom.map((p) => _PersonRow(person: p)),
          const SizedBox(height: 18),
          const _InviteLinkCard(),
          const SizedBox(height: 14),
          const _ActionRow(),
        ],
      ),
    );
  }
}

// ── Static fixtures (v1 UI shell) ──────────────────────────────────────────

class _Person {
  const _Person({
    required this.name,
    required this.subtitle,
    required this.initials,
    required this.gradient,
  });

  final String name;
  final String subtitle;
  final String initials;
  final Gradient gradient;
}

const _mockRoom = <_Person>[
  _Person(
    name: 'Alex (you)',
    subtitle: 'Host · Pixel 7 Pro',
    initials: 'AK',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
    ),
  ),
  _Person(
    name: 'Sarah Mendez',
    subtitle: 'iPhone 15 · joined 12m ago',
    initials: 'SM',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF22D3EE), Color(0xFF6366F1)],
    ),
  ),
  _Person(
    name: 'Jamie Liu',
    subtitle: 'Apple TV · joined 8m ago',
    initials: 'JL',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ),
  ),
  _Person(
    name: 'Theo Park',
    subtitle: 'iPad · joined 4m ago',
    initials: 'TP',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF10B981), Color(0xFF22D3EE)],
    ),
  ),
];

const _mockInviteLink = 'fluxora.io/w/aTl2-xK9p';

// ── Widgets ────────────────────────────────────────────────────────────────

class _ShellNote extends StatelessWidget {
  const _ShellNote();

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
          const Icon(
            Icons.info_outline,
            size: 16,
            color: AppColors.violetTint,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Sync engine ships in v1.1 — this is the UI preview.',
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

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF050810), Color(0xFF2A3A6A)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.cyan,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'LIVE · NOW PLAYING',
                      style: AppTypography.eyebrow.copyWith(
                        color: AppColors.cyan,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: AppTypography.displayV2.copyWith(
                    color: AppColors.textBright,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Static preview · sync coming soon',
                  style: AppTypography.captionV2.copyWith(
                    color: const Color(0xB3FFFFFF),
                    fontSize: 11.5,
                  ),
                ),
              ],
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

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person});
  final _Person person;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: person.gradient,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              person.initials,
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
                  person.name,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBright,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  person.subtitle,
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textMutedV2,
                  ),
                ),
              ],
            ),
          ),
          // Stub-disabled — chat sidecar lives with the sync engine in
          // v1.1.  Render the icon greyed-out so the surface looks
          // complete without hinting that tap-to-chat works today.
          const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 16,
            color: AppColors.textDim,
          ),
        ],
      ),
    );
  }
}

class _InviteLinkCard extends StatelessWidget {
  const _InviteLinkCard();

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
            'INVITE LINK',
            style: AppTypography.eyebrow.copyWith(
              color: AppColors.textDim,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.bgRoot,
                    border: Border.all(color: AppColors.borderSubtle),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    _mockInviteLink,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 12,
                      color: AppColors.textBright,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const SizedBox(
                width: 44,
                height: 44,
                child: _CopyButton(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Copy invite link',
      child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        await Clipboard.setData(
          const ClipboardData(text: _mockInviteLink),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invite link copied — sync engine ships in v1.1',
            ),
            backgroundColor: AppColors.violet,
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.pillBgPurple,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.copy_rounded,
          size: 16,
          color: AppColors.violet,
        ),
      ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: SizedBox(
            height: 46,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: const Color(0x1AEF4444),
                side: const BorderSide(color: Color(0x4DEF4444)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/home'),
              child: Text(
                'Leave',
                style: AppTypography.body.copyWith(
                  color: const Color(0xFFF87171),
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 46,
            child: FluxButton(
              icon: Icons.play_arrow_rounded,
              // Sync engine doesn't exist; tapping this surfaces the
              // shell-only state instead of pretending to start a sync.
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Group sync ships in v1.1 — playback resumes locally only.',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              child: const Text('Resume for everyone'),
            ),
          ),
        ),
      ],
    );
  }
}
