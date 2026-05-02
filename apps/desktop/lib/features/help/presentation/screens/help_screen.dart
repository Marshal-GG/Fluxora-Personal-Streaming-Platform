/// Help screen — static reference + support links.
///
/// Matches `docs/11_design/desktop_prototype/app/pages/help.jsx`.
/// No cubit, no repository. Left column: keyboard shortcuts.
/// Right column: support links + system status + diagnostics.
library;

import 'package:flutter/material.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';

import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/status_dot.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.s28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Help & Support',
            subtitle: 'Quick reference, keyboard shortcuts, and support resources',
          ),
          Expanded(child: _HelpBody()),
          SizedBox(height: AppSpacing.s28),
        ],
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _HelpBody extends StatelessWidget {
  const _HelpBody();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column — shortcuts + FAQ
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Shortcuts header card
                FluxCard(
                  padding: 22,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF6366F1),
                              Color(0xFFA855F7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.keyboard_outlined,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Keyboard Shortcuts',
                            style: AppTypography.body.copyWith(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Speed up your workflow with these key bindings',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textMutedV2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (final group in _kShortcutGroups)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ShortcutGroup(group: group),
                  ),
                const SizedBox(height: 14),
                // FAQ
                Text(
                  'Frequently Asked Questions',
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 10),
                for (final qa in _kFaq)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _FaqItem(question: qa.$1, answer: qa.$2),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        // Right column — 320 px fixed
        const SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _GetHelpCard(),
                SizedBox(height: 14),
                _StatusCard(),
                SizedBox(height: 14),
                _DiagnosticsCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Shortcut data ─────────────────────────────────────────────────────────────

typedef _ShortcutGroupData = ({
  String group,
  List<(String action, String keys)> items,
});

const List<_ShortcutGroupData> _kShortcutGroups = [
  (
    group: 'Navigation',
    items: [
      ('Go to Dashboard', 'Ctrl G D'),
      ('Go to Library', 'Ctrl G L'),
      ('Go to Clients', 'Ctrl G C'),
      ('Go to Settings', 'Ctrl ,'),
    ],
  ),
  (
    group: 'General',
    items: [
      ('Refresh current view', 'Ctrl R'),
      ('Open Help', 'F1'),
      ('Toggle notifications', 'Ctrl Shift N'),
    ],
  ),
];

// ── Shortcut group ────────────────────────────────────────────────────────────

class _ShortcutGroup extends StatelessWidget {
  const _ShortcutGroup({required this.group});
  final _ShortcutGroupData group;

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Text(
              group.group,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ),
          for (final item in group.items)
            _ShortcutRow(action: item.$1, keys: item.$2),
        ],
      ),
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({required this.action, required this.keys});
  final String action;
  final String keys;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x08FFFFFF))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              action,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textBody,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final k in keys.split(' ')) ...[
                _Kbd(label: k),
                const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Kbd extends StatelessWidget {
  const _Kbd({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x0DFFFFFF),
        border: Border.all(color: const Color(0x1AFFFFFF)),
        borderRadius: BorderRadius.circular(5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0DFFFFFF),
            offset: Offset(0, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'JetBrainsMono',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE2E8F0),
        ),
      ),
    );
  }
}

// ── FAQ ───────────────────────────────────────────────────────────────────────

const List<(String, String)> _kFaq = [
  (
    'How do I add a media library?',
    'Go to Library → click "Add Library", give it a name and pick a folder on your server. Fluxora will scan and index the contents automatically.',
  ),
  (
    'Why is FFmpeg required?',
    'Fluxora uses FFmpeg for on-the-fly transcoding and HLS segment generation. It must be installed separately because it cannot be bundled in the server executable.',
  ),
  (
    'How does device pairing work?',
    'The mobile or desktop client discovers the server on the same LAN via mDNS. You approve the pairing request in the Clients screen. A secure bearer token is then issued to the client.',
  ),
  (
    'What is the difference between LAN and WAN streaming?',
    'LAN streaming is direct — no internet, no latency overhead. WAN streaming (Plus+) routes through a Cloudflare Tunnel when you are away from home, with an 8-second timeout before falling back.',
  ),
  (
    'How do I upgrade my tier?',
    'Go to Subscription → Plans & Pricing and select the plan you want. You will be directed to the Polar payment portal to complete the purchase.',
  ),
  (
    'The server is unreachable — what should I check?',
    'Verify the server is running and the URL in Settings matches. On Windows, check that the firewall allows port 8080. Ensure FFmpeg is installed and visible on PATH.',
  ),
];

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              button: true,
              expanded: _open,
              label: 'FAQ: ${widget.question}',
              child: GestureDetector(
                onTap: () => setState(() => _open = !_open),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.question,
                            style: AppTypography.bodySmall.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Icon(
                          _open
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: AppColors.textMutedV2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_open)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Color(0x08FFFFFF))),
                ),
                child: Text(
                  widget.answer,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textMutedV2,
                    height: 1.6,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Right-column cards ────────────────────────────────────────────────────────

class _GetHelpCard extends StatelessWidget {
  const _GetHelpCard();

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Get Help',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _kLinks.length; i++)
            _LinkRow(
              icon: _kLinks[i].$1,
              title: _kLinks[i].$2,
              sub: _kLinks[i].$3,
              url: _kLinks[i].$4,
              hasDivider: i > 0,
            ),
        ],
      ),
    );
  }
}

const List<(IconData, String, String, String?)> _kLinks = [
  (
    Icons.menu_book_outlined,
    'Documentation',
    'User guides + API reference',
    'https://github.com/marshalx/fluxora',
  ),
  (
    Icons.group_outlined,
    'Community',
    'Self-hosters forum',
    'https://github.com/marshalx/fluxora/discussions',
  ),
  (
    Icons.bug_report_outlined,
    'Report an Issue',
    'GitHub issue tracker',
    'https://github.com/marshalx/fluxora/issues',
  ),
  (
    Icons.new_releases_outlined,
    "What's New",
    'Latest releases',
    'https://github.com/marshalx/fluxora/releases',
  ),
];

class _LinkRow extends StatefulWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.sub,
    required this.url,
    required this.hasDivider,
  });

  final IconData icon;
  final String title;
  final String sub;
  final String? url;
  final bool hasDivider;

  @override
  State<_LinkRow> createState() => _LinkRowState();
}

class _LinkRowState extends State<_LinkRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(
        button: true,
        link: true,
        label: '${widget.title}, opens external link',
        child: GestureDetector(
          onTap: () {
            // TODO(M8): open URL via url_launcher once added
          },
          child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: widget.hasDivider
                ? const Border(
                    top: BorderSide(color: Color(0x0AFFFFFF)),
                  )
                : null,
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: _hovered
                    ? AppColors.violet
                    : AppColors.violetTint,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 12.5,
                        color: _hovered
                            ? AppColors.textBright
                            : AppColors.textBody,
                      ),
                    ),
                    Text(
                      widget.sub,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textDim,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new_outlined,
                size: 11,
                color: AppColors.textFaint,
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard();

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < _kStatus.length; i++)
            _StatusRow(
              label: _kStatus[i].$1,
              status: _kStatus[i].$2,
              hasDivider: i > 0,
            ),
        ],
      ),
    );
  }
}

const List<(String, DotStatus)> _kStatus = [
  ('Streaming Service', DotStatus.online),
  ('Authentication', DotStatus.online),
  ('Local Network', DotStatus.online),
  ('Update Servers', DotStatus.idle),
];

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.status,
    required this.hasDivider,
  });

  final String label;
  final DotStatus status;
  final bool hasDivider;

  @override
  Widget build(BuildContext context) {
    final isOnline = status == DotStatus.online;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        border: hasDivider
            ? const Border(top: BorderSide(color: Color(0x0AFFFFFF)))
            : null,
      ),
      child: Row(
        children: [
          StatusDot(status: status),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textMutedV2,
              ),
            ),
          ),
          Text(
            isOnline ? 'Operational' : 'Degraded',
            style: AppTypography.bodySmall.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isOnline
                  ? const Color(0xFF10B981)
                  : const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiagnosticsCard extends StatelessWidget {
  const _DiagnosticsCard();

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Diagnostics',
            style: AppTypography.body.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a support bundle with logs, configuration, and system info.',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textDim,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const SizedBox(
            width: double.infinity,
            child: FluxButton(
              variant: FluxButtonVariant.primary,
              icon: Icons.download_outlined,
              fullWidth: true,
              // TODO(M8): implement support bundle export
              onPressed: null,
              child: Text('Generate Bundle'),
            ),
          ),
        ],
      ),
    );
  }
}
