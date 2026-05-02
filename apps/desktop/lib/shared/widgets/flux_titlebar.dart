/// FluxTitlebar — custom 36 px window chrome.
///
/// Translates `docs/11_design/prototype/app/desktop/app.jsx` lines 32–53 into
/// Flutter. The OS title bar is hidden via `TitleBarStyle.hidden` in
/// `main.dart`; this widget renders the replacement: brand wordmark + tagline
/// (left, draggable region), help + notifications icon buttons (mid-right),
/// minimize / maximize / close window controls (far right).
///
/// All window operations are routed through `window_manager`. The drag region
/// is provided by `DragToMoveArea`; double-clicking it toggles maximize to
/// match native Windows behaviour.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:window_manager/window_manager.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/widgets/fluxora_logo.dart';

import 'package:fluxora_desktop/shared/widgets/flux_shell.dart';

/// Pixel-matched 36 px titlebar.
///
/// The widget listens to window-state changes (maximize / unmaximize) so the
/// middle window-control button can swap its icon between
/// `Icons.crop_square` (will-maximize) and `Icons.filter_none` (will-restore).
class FluxTitlebar extends StatefulWidget {
  const FluxTitlebar({super.key});

  @override
  State<FluxTitlebar> createState() => _FluxTitlebarState();
}

class _FluxTitlebarState extends State<FluxTitlebar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _syncMaximizedState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _syncMaximizedState() async {
    final maximized = await windowManager.isMaximized();
    if (mounted && maximized != _isMaximized) {
      setState(() => _isMaximized = maximized);
    }
  }

  @override
  void onWindowMaximize() => _syncMaximizedState();

  @override
  void onWindowUnmaximize() => _syncMaximizedState();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: const BoxDecoration(
        // Prototype line 37: rgba(6,4,16,0.9)
        color: Color(0xE6060410),
        border: Border(
          bottom: BorderSide(color: Color(0x0AFFFFFF)),
        ),
      ),
      child: Row(
        children: [
          // ── Drag region: wordmark + tagline ─────────────────────────────
          // Left edge gets 16 px breathing room; window controls on the
          // right sit flush with the window edge (Windows-11 native).
          const Expanded(
            child: DragToMoveArea(
              child: Padding(
                padding: EdgeInsets.only(left: 16),
                child: Row(
                  children: [
                    FluxoraWordmark(height: 13),
                    SizedBox(width: 10),
                    Text(
                      '· Stream. Sync. Anywhere.',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: AppColors.textDim,
                        height: 1.0,
                      ),
                    ),
                    Expanded(child: SizedBox.expand()),
                  ],
                ),
              ),
            ),
          ),

          // ── App-action icons: help + notifications ─────────────────────
          _IconActionButton(
            icon: Icons.help_outline,
            tooltip: 'Help',
            onTap: () => context.go('/help'),
          ),
          const SizedBox(width: 4),
          _NotificationsBellButton(),
          const SizedBox(width: 8),

          // ── Window controls: minimize / maximize / close ───────────────
          // Each button is 46 × 36 (Windows-11 caption-button geometry),
          // sits flush with the window's right edge, no inter-button gaps.
          // Glyphs come from Segoe Fluent Icons (Win 11) with Segoe MDL2
          // Assets fallback (Win 10) — these are the exact characters the
          // OS uses for native caption buttons.
          _WindowControlButton(
            glyph: '', // ChromeMinimize
            tooltip: 'Minimize',
            onTap: () => windowManager.minimize(),
          ),
          _WindowControlButton(
            glyph: _isMaximized ? '' : '', // ChromeRestore / ChromeMaximize
            tooltip: _isMaximized ? 'Restore' : 'Maximize',
            onTap: () async {
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            },
          ),
          _WindowControlButton(
            glyph: '', // ChromeClose
            tooltip: 'Close',
            isCloseButton: true,
            onTap: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}

// ─── Help / bell pill button (26×26, rgba bg + border) ────────────────────────

class _IconActionButton extends StatefulWidget {
  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_IconActionButton> createState() => _IconActionButtonState();
}

class _IconActionButtonState extends State<_IconActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0x14FFFFFF)
                  : const Color(0x08FFFFFF),
              border: Border.all(color: const Color(0x0DFFFFFF)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(widget.icon, size: 13, color: AppColors.textMutedV2),
          ),
        ),
      ),
    );
  }
}

// ─── Notifications bell with violet status dot ────────────────────────────────

class _NotificationsBellButton extends StatefulWidget {
  @override
  State<_NotificationsBellButton> createState() =>
      _NotificationsBellButtonState();
}

class _NotificationsBellButtonState extends State<_NotificationsBellButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final panel = NotificationsPanelScope.of(context);
    return Tooltip(
      message: 'Notifications',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: panel.toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _hovered
                  ? const Color(0x14FFFFFF)
                  : const Color(0x08FFFFFF),
              border: Border.all(color: const Color(0x0DFFFFFF)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Stack(
              clipBehavior: Clip.none,
              children: [
                Center(
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 13,
                    color: AppColors.textMutedV2,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: _BellDot(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BellDot extends StatelessWidget {
  const _BellDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.violet,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.violet.withValues(alpha: 0.6),
            blurRadius: 6,
            spreadRadius: 0,
          ),
        ],
      ),
    );
  }
}

// ─── Window control button (Windows-11 native caption-button style) ──────────
//
// Geometry — 46 × 36 px each, sits flush with the window edge, no gaps. This
// matches the Windows 11 caption-button strip exactly so the muscle memory
// "click-the-top-right-corner-to-close" gesture works without users having
// to aim for a smaller target.
//
// Min / Max:
//   default → transparent
//   hover   → rgba(255,255,255,0.06)  (subtle highlight)
//   pressed → rgba(255,255,255,0.10)
//
// Close (`isCloseButton: true`):
//   default → transparent
//   hover   → #C42B1C (Windows 11 close-red), icon turns white
//   pressed → #B72516 (slightly darker)

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.glyph,
    required this.tooltip,
    required this.onTap,
    this.isCloseButton = false,
  });

  /// The Segoe Fluent Icons / Segoe MDL2 Assets codepoint to render. Pass the
  /// literal character (e.g. `''` for ChromeMinimize). Using these
  /// fonts gives us pixel-identical caption glyphs to native Windows.
  final String glyph;
  final String tooltip;
  final VoidCallback onTap;

  /// When true, applies the Windows close-button red hover treatment and
  /// inverts the icon to white on hover/press.
  final bool isCloseButton;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  bool _hovered = false;
  bool _pressed = false;

  static const _hoverNeutral = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const _pressNeutral = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)
  static const _hoverClose = Color(0xFFC42B1C);
  static const _pressClose = Color(0xFFB72516);

  Color get _bgColor {
    if (widget.isCloseButton) {
      if (_pressed) return _pressClose;
      if (_hovered) return _hoverClose;
      return Colors.transparent;
    }
    if (_pressed) return _pressNeutral;
    if (_hovered) return _hoverNeutral;
    return Colors.transparent;
  }

  Color get _iconColor {
    if (widget.isCloseButton && (_hovered || _pressed)) return Colors.white;
    return _hovered ? AppColors.textBody : AppColors.textMutedV2;
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          _pressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 46,
            height: 36,
            color: _bgColor,
            child: Center(
              child: Text(
                widget.glyph,
                style: TextStyle(
                  // Win 11 ships Segoe Fluent Icons; Win 10 falls back to
                  // Segoe MDL2 Assets. Both have the same caption-button
                  // codepoints (E921 / E922 / E923 / E8BB).
                  fontFamily: 'Segoe Fluent Icons',
                  fontFamilyFallback: const ['Segoe MDL2 Assets'],
                  fontSize: 10,
                  color: _iconColor,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
