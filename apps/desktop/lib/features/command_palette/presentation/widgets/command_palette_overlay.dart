/// CommandPaletteOverlay — the Cmd+K modal search overlay.
///
/// 600 × ~420 px frosted-glass card, centered on screen.
/// Keyboard: Up/Down moves highlight, Enter executes, Escape closes.
/// Navigation commands call [GoRouter.go]; action commands invoke their
/// [VoidCallback] and close the palette.
library;

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';

import 'package:fluxora_desktop/features/command_palette/data/command_registry.dart';
import 'package:fluxora_desktop/features/command_palette/domain/command.dart';
import 'package:fluxora_desktop/features/command_palette/presentation/notifier/command_palette_notifier.dart';

// ── Public widget ──────────────────────────────────────────────────────────────

/// Full-screen backdrop + centered palette card.
///
/// Mount this inside the [FluxShell] Stack so it renders above all content.
/// Pass the shared [CommandPaletteNotifier] (owned by [_ShellBodyState]).
class CommandPaletteOverlay extends StatefulWidget {
  const CommandPaletteOverlay({
    super.key,
    required this.notifier,
  });

  final CommandPaletteNotifier notifier;

  @override
  State<CommandPaletteOverlay> createState() => _CommandPaletteOverlayState();
}

class _CommandPaletteOverlayState extends State<CommandPaletteOverlay> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late List<Command> _all;
  late List<Command> _filtered;

  static const double _itemHeight = 56.0;

  @override
  void initState() {
    super.initState();
    _all = buildCommandRegistry(context);
    _filtered = widget.notifier.filter(_all);
    widget.notifier.addListener(_onNotifierChange);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    widget.notifier.removeListener(_onNotifierChange);
    super.dispose();
  }

  void _onNotifierChange() {
    if (!mounted) return;
    setState(() {
      _filtered = widget.notifier.filter(_all);
    });
    _scrollToHighlight();
  }

  void _scrollToHighlight() {
    final idx = widget.notifier.highlightIndex;
    final offset = idx * _itemHeight;
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        offset.clamp(0.0, _scrollCtrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
      );
    }
  }

  void _execute(Command cmd) {
    widget.notifier.close();
    if (cmd.routePath != null) {
      GoRouter.of(context).go(cmd.routePath!);
    } else {
      cmd.action?.call();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        widget.notifier.close();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
        widget.notifier.moveHighlight(1, _filtered.length);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
        widget.notifier.moveHighlight(-1, _filtered.length);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (_filtered.isNotEmpty) {
          _execute(_filtered[widget.notifier.highlightIndex]);
        }
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Command palette',
      child: KeyboardListener(
        focusNode: FocusNode()..requestFocus(),
        onKeyEvent: (event) => _handleKeyEvent(FocusNode(), event),
        child: GestureDetector(
          onTap: widget.notifier.close,
          child: ColoredBox(
            color: Colors.black54,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Center(
                child: GestureDetector(
                  // Prevent taps inside the card from closing the palette.
                  onTap: () {},
                  child: _PaletteCard(
                    searchCtrl: _searchCtrl,
                    scrollCtrl: _scrollCtrl,
                    filtered: _filtered,
                    notifier: widget.notifier,
                    onExecute: _execute,
                    onQueryChanged: (v) {
                      widget.notifier.setQuery(v);
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Palette card ───────────────────────────────────────────────────────────────

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.searchCtrl,
    required this.scrollCtrl,
    required this.filtered,
    required this.notifier,
    required this.onExecute,
    required this.onQueryChanged,
  });

  final TextEditingController searchCtrl;
  final ScrollController scrollCtrl;
  final List<Command> filtered;
  final CommandPaletteNotifier notifier;
  final ValueChanged<Command> onExecute;
  final ValueChanged<String> onQueryChanged;

  static const double _cardWidth = 600;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _cardWidth,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF01A1830), // ~94% opaque surface
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: AppColors.borderSubtle),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 40,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Search input ──────────────────────────────────────────────
              _SearchRow(
                controller: searchCtrl,
                onChanged: onQueryChanged,
              ),

              // ── Divider ───────────────────────────────────────────────────
              const Divider(
                height: 1,
                thickness: 1,
                color: Color(0x14FFFFFF),
              ),

              // ── Results list ──────────────────────────────────────────────
              _ResultsList(
                filtered: filtered,
                notifier: notifier,
                scrollCtrl: scrollCtrl,
                onExecute: onExecute,
              ),

              // ── Footer hint ───────────────────────────────────────────────
              const _FooterHint(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Search row ─────────────────────────────────────────────────────────────────

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s18,
        vertical: AppSpacing.s14,
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: AppColors.textDim),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: true,
              onChanged: onChanged,
              style: AppTypography.body.copyWith(
                color: AppColors.textBright,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search commands…',
                hintStyle: AppTypography.body.copyWith(
                  color: AppColors.textFaint,
                  fontSize: 15,
                ),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          // Escape badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: Text(
              'Esc',
              style: AppTypography.monoMicro.copyWith(
                color: AppColors.textDim,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Results list ───────────────────────────────────────────────────────────────

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.filtered,
    required this.notifier,
    required this.scrollCtrl,
    required this.onExecute,
  });

  final List<Command> filtered;
  final CommandPaletteNotifier notifier;
  final ScrollController scrollCtrl;
  final ValueChanged<Command> onExecute;

  static const double _maxHeight = 336; // 6 × 56

  @override
  Widget build(BuildContext context) {
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.s28,
          horizontal: AppSpacing.s18,
        ),
        child: Center(
          child: Text(
            'No commands found',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textDim,
            ),
          ),
        ),
      );
    }

    return ListenableBuilder(
      listenable: notifier,
      builder: (_, _) => ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _maxHeight),
        child: ListView.builder(
          controller: scrollCtrl,
          shrinkWrap: true,
          itemCount: filtered.length,
          itemExtent: 56,
          itemBuilder: (_, i) => _CommandItem(
            command: filtered[i],
            isHighlighted: notifier.highlightIndex == i,
            onTap: () => onExecute(filtered[i]),
            onHover: () => notifier.setHighlight(i),
          ),
        ),
      ),
    );
  }
}

// ── Single command item ────────────────────────────────────────────────────────

class _CommandItem extends StatelessWidget {
  const _CommandItem({
    required this.command,
    required this.isHighlighted,
    required this.onTap,
    required this.onHover,
  });

  final Command command;
  final bool isHighlighted;
  final VoidCallback onTap;
  final VoidCallback onHover;

  @override
  Widget build(BuildContext context) {
    final bg = isHighlighted
        ? const Color(0x24A855F7) // rgba(168,85,247,0.14)
        : Colors.transparent;

    return Semantics(
      label: command.label,
      hint: command.subtitle,
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => onHover(),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            color: bg,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s18,
              vertical: AppSpacing.s10,
            ),
            child: Row(
              children: [
                // Icon
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Center(
                    child: Icon(
                      command.icon ?? Icons.terminal,
                      size: 16,
                      color: isHighlighted
                          ? AppColors.violetTint
                          : AppColors.textDim,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                // Label + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        command.label,
                        style: AppTypography.body.copyWith(
                          color: isHighlighted
                              ? AppColors.textBright
                              : AppColors.textBody,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (command.subtitle != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          command.subtitle!,
                          style: AppTypography.captionV2.copyWith(
                            color: AppColors.textDim,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // Enter badge on highlighted row
                if (isHighlighted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x14FFFFFF),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0x1FFFFFFF)),
                    ),
                    child: Text(
                      '↵',
                      style: AppTypography.monoMicro.copyWith(
                        color: AppColors.textDim,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Footer hint ────────────────────────────────────────────────────────────────

class _FooterHint extends StatelessWidget {
  const _FooterHint();

  @override
  Widget build(BuildContext context) {
    const keyStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: AppColors.textDim,
    );
    const sepStyle = TextStyle(
      fontFamily: 'Inter',
      fontSize: 10,
      color: AppColors.textFaint,
    );

    Widget kbd(String label) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0x0AFFFFFF),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0x14FFFFFF)),
          ),
          child: Text(label, style: keyStyle),
        );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s18,
        vertical: AppSpacing.s10,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x0AFFFFFF))),
      ),
      child: Row(
        children: [
          kbd('↑↓'),
          const SizedBox(width: 6),
          const Text('navigate', style: sepStyle),
          const SizedBox(width: AppSpacing.s14),
          kbd('↵'),
          const SizedBox(width: 6),
          const Text('select', style: sepStyle),
          const SizedBox(width: AppSpacing.s14),
          kbd('Esc'),
          const SizedBox(width: 6),
          const Text('close', style: sepStyle),
        ],
      ),
    );
  }
}
