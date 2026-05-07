/// Shared form widgets for the Groups feature.
///
/// Lifted from `groups_screen.dart` at M4 of
/// `docs/10_planning/14_groups_management_page.md` so both the legacy
/// list-page detail panel AND the dedicated Group edit page can consume
/// the same surfaces.  Class names dropped the leading `_` prefix to be
/// library-public; supporting widgets (`_HourField`, `_ChevronButton`,
/// `_ClientPickRow`) stay private to this file.
library;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/client_list_item.dart';
import 'package:fluxora_core/entities/enums.dart';
import 'package:fluxora_core/entities/group.dart';
import 'package:fluxora_core/entities/library.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';
import 'package:logger/logger.dart';
import 'package:fluxora_desktop/features/clients/domain/repositories/clients_repository.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_dialog.dart';
import 'package:fluxora_desktop/shared/widgets/flux_switch.dart';

// ── Time window helpers ────────────────────────────────────────────────────

/// Day-of-week order matches Python's `datetime.weekday()` convention used
/// server-side: 0=Mon … 6=Sun.  Server `_in_window` filters by exactly this
/// list so any reordering here would silently change which days the gate
/// matches.
const _kWeekdayLabels = <String>['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Format a [TimeWindow] for the live preview caption.  Handles midnight
/// wrap (`endH <= startH`), zero-length windows, and condenses the day list
/// to "Mon-Fri" / "Weekends" / "All week" / "Mon, Wed, Fri" depending on
/// shape.  Returns null when the window is null or zero-length.
String? formatTimeWindow(TimeWindow? w) {
  if (w == null) return null;
  if (w.startH == w.endH) return 'Disabled (zero-length window)';

  String hour(int h) => '${h.toString().padLeft(2, '0')}:00';
  final range = '${hour(w.startH)}-${hour(w.endH)}';

  // Day list compaction.  Common patterns get friendly names; arbitrary
  // sets fall back to the comma-joined abbreviation.
  final days = [...w.days]..sort();
  if (days.length == 7) return 'All week, $range';
  if (days.length == 5 && days.every((d) => d <= 4)) return 'Mon-Fri, $range';
  if (days.length == 2 && days.contains(5) && days.contains(6)) {
    return 'Weekends, $range';
  }
  if (days.isEmpty) return 'No days selected';
  final names = days.map((d) => _kWeekdayLabels[d]).join(', ');
  return '$names, $range';
}

// ── GroupRestrictionsForm ──────────────────────────────────────────────────

/// Inline restriction editor — owns local toggle + value state and calls
/// [onChanged] whenever any field changes so the parent can hold the
/// assembled [GroupRestrictions?] for its Save handler.
///
/// Toggles control nullability: when "Restrict streaming time" is off the
/// emitted restrictions carry `timeWindow: null`; when on, the picker's
/// values flow through.  Same pattern for "Restrict to specific
/// libraries".  Bandwidth + max rating are advisory in v1 (server doesn't
/// enforce; see `docs/10_planning/12_groups_remediation_plan.md` §4) so
/// they're rendered disabled with explanatory tooltips — operator sees the
/// surface exists without us pretending they work.
class GroupRestrictionsForm extends StatefulWidget {
  const GroupRestrictionsForm({
    super.key,
    required this.libraries,
    required this.initial,
    required this.onChanged,
  });

  /// Library catalog used by the allowlist picker.  Empty list = the
  /// libraries fetch failed or the operator has no libraries; the picker
  /// renders a placeholder explaining why nothing is selectable.
  final List<Library> libraries;
  final GroupRestrictions? initial;
  final ValueChanged<GroupRestrictions?> onChanged;

  @override
  State<GroupRestrictionsForm> createState() => _GroupRestrictionsFormState();
}

class _GroupRestrictionsFormState extends State<GroupRestrictionsForm> {
  bool _restrictTime = false;
  bool _restrictLibraries = false;
  TimeWindow _windowDraft = const TimeWindow(
    startH: 18,
    endH: 22,
    days: [0, 1, 2, 3, 4, 5, 6],
  );
  Set<String> _allowedLibraries = <String>{};

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    if (r != null) {
      if (r.timeWindow != null) {
        _restrictTime = true;
        _windowDraft = r.timeWindow!;
      }
      if (r.allowedLibraries != null) {
        _restrictLibraries = true;
        _allowedLibraries = r.allowedLibraries!.toSet();
      }
    }
  }

  void _emit() {
    final hasRestriction = _restrictTime || _restrictLibraries;
    if (!hasRestriction) {
      widget.onChanged(null);
      return;
    }
    widget.onChanged(
      GroupRestrictions(
        timeWindow: _restrictTime ? _windowDraft : null,
        allowedLibraries:
            _restrictLibraries ? _allowedLibraries.toList() : null,
        // Bandwidth + maxRating left null — advisory, server doesn't act
        // on them, so persisting whatever the disabled controls show
        // would just clutter the DB.  When the server starts enforcing
        // them (v2), wire the controls and pass values through here.
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Time window ───────────────────────────────────────────────
        SectionToggleHeader(
          icon: Icons.schedule_outlined,
          label: 'Restrict streaming time',
          value: _restrictTime,
          onChanged: (v) {
            setState(() => _restrictTime = v);
            _emit();
          },
        ),
        if (_restrictTime) ...[
          const SizedBox(height: AppSpacing.s8),
          TimeWindowPicker(
            value: _windowDraft,
            onChanged: (w) {
              setState(() => _windowDraft = w);
              _emit();
            },
          ),
        ],
        const SizedBox(height: AppSpacing.s12),

        // ── Library allowlist ─────────────────────────────────────────
        SectionToggleHeader(
          icon: Icons.video_library_outlined,
          label: 'Restrict to specific libraries',
          value: _restrictLibraries,
          onChanged: (v) {
            setState(() {
              _restrictLibraries = v;
              if (v && _allowedLibraries.isEmpty) {
                // Pre-select all libraries when the operator first
                // toggles this on so the gate doesn't immediately deny
                // every stream.  They can untick anything they want
                // restricted.
                _allowedLibraries =
                    widget.libraries.map((l) => l.id).toSet();
              }
            });
            _emit();
          },
        ),
        if (_restrictLibraries) ...[
          const SizedBox(height: AppSpacing.s8),
          LibraryAllowlistPicker(
            libraries: widget.libraries,
            selected: _allowedLibraries,
            onToggle: (id) {
              setState(() {
                if (_allowedLibraries.contains(id)) {
                  _allowedLibraries = {..._allowedLibraries}..remove(id);
                } else {
                  _allowedLibraries = {..._allowedLibraries, id};
                }
              });
              _emit();
            },
          ),
        ],
        const SizedBox(height: AppSpacing.s12),

        // ── Advisory fields (recorded but not enforced — see §4 of the
        //     remediation plan).  Disabled with a tooltip so the operator
        //     understands the surface exists for forward-compat.
        const AdvisoryFieldsSection(),
      ],
    );
  }
}

// ── SectionToggleHeader ────────────────────────────────────────────────────

/// Icon + label + right-aligned [FluxSwitch] header used for each
/// restriction subsection AND the page-level Active/Inactive status row
/// on the Overview tab.
class SectionToggleHeader extends StatelessWidget {
  const SectionToggleHeader({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textMutedV2),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textBright,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        FluxSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}

// ── TimeWindowPicker ───────────────────────────────────────────────────────

/// Time-window editor — start hour, end hour, and day-of-week chips.
/// Server enforces both the day list AND the hour range; midnight wrap
/// (`endH <= startH`) is supported by `_in_window`.  This widget exposes a
/// live preview caption ("Mon-Fri 18:00-22:00") so the operator can verify
/// the assembled rule before saving.
class TimeWindowPicker extends StatelessWidget {
  const TimeWindowPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final TimeWindow value;
  final ValueChanged<TimeWindow> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hour pickers
          Row(
            children: [
              Expanded(
                child: _HourField(
                  label: 'Start',
                  value: value.startH,
                  onChanged: (h) =>
                      onChanged(_copyWindow(value, startH: h)),
                ),
              ),
              const SizedBox(width: AppSpacing.s10),
              Expanded(
                child: _HourField(
                  label: 'End',
                  value: value.endH,
                  onChanged: (h) =>
                      onChanged(_copyWindow(value, endH: h)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),

          // Day-of-week chip row — multi-select, server-side day index.
          Text(
            'Days',
            style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
          ),
          const SizedBox(height: AppSpacing.s4),
          Wrap(
            spacing: 4,
            children: List.generate(7, (i) {
              final selected = value.days.contains(i);
              return GestureDetector(
                onTap: () {
                  final next = [...value.days];
                  if (selected) {
                    next.remove(i);
                  } else {
                    next.add(i);
                  }
                  onChanged(_copyWindow(value, days: next));
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0x2EA855F7)
                          : const Color(0x08FFFFFF),
                      border: Border.all(
                        color: selected
                            ? const Color(0x80A855F7)
                            : const Color(0x0FFFFFFF),
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Text(
                      _kWeekdayLabels[i],
                      style: TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.violetSoft
                            : AppColors.textMutedV2,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppSpacing.s10),

          // Live preview — what the server will see.
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 12, color: AppColors.textDim),
              const SizedBox(width: AppSpacing.s6),
              Expanded(
                child: Text(
                  formatTimeWindow(value) ?? '(no window)',
                  style: AppTypography.captionV2
                      .copyWith(color: AppColors.textMutedV2),
                ),
              ),
            ],
          ),
          if (value.endH <= value.startH && value.endH != value.startH) ...[
            const SizedBox(height: AppSpacing.s4),
            Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 12, color: AppColors.amber),
                const SizedBox(width: AppSpacing.s6),
                Expanded(
                  child: Text(
                    'Window wraps midnight — '
                    '${value.startH.toString().padLeft(2, '0')}:00 to '
                    '${value.endH.toString().padLeft(2, '0')}:00 next day.',
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.amber.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ],
          // Timezone note — the server uses its local time.  Self-hosted
          // single-house deployments rarely care; remote-paired clients
          // across timezones do.  Documented limitation per
          // `12_groups_remediation_plan.md` §4.3.
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Times are evaluated in the server\'s local timezone.',
            style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
          ),
        ],
      ),
    );
  }

  static TimeWindow _copyWindow(
    TimeWindow base, {
    int? startH,
    int? endH,
    List<int>? days,
  }) {
    return TimeWindow(
      startH: startH ?? base.startH,
      endH: endH ?? base.endH,
      days: days ?? base.days,
    );
  }
}

/// Numeric hour selector (0-23) rendered as a label + read-only field with
/// up/down chevrons.  Avoids dragging in a heavyweight time picker for a
/// 24-value range — this is faster to operate than a clock spinner.
class _HourField extends StatelessWidget {
  const _HourField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    String fmt(int h) => '${h.toString().padLeft(2, '0')}:00';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.captionV2.copyWith(color: AppColors.textDim),
        ),
        const SizedBox(height: AppSpacing.s4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x08FFFFFF),
            border: Border.all(color: const Color(0x14FFFFFF)),
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  fmt(value),
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textBright,
                  ),
                ),
              ),
              _ChevronButton(
                icon: Icons.keyboard_arrow_up_rounded,
                onTap: () => onChanged((value + 1) % 24),
              ),
              _ChevronButton(
                icon: Icons.keyboard_arrow_down_rounded,
                onTap: () => onChanged((value - 1 + 24) % 24),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(icon, size: 14, color: AppColors.textMutedV2),
        ),
      ),
    );
  }
}

// ── LibraryAllowlistPicker ─────────────────────────────────────────────────

/// Multi-select chip row of library names.  Each chip is independently
/// tickable; the parent passes a set of selected library ids and a toggle
/// callback.  Empty libraries list (fetch failed or operator has no
/// libraries) renders an explanatory placeholder instead of a blank wrap
/// — without it the operator would see the toggle on but no chips and
/// wonder if the UI was broken.
class LibraryAllowlistPicker extends StatelessWidget {
  const LibraryAllowlistPicker({
    super.key,
    required this.libraries,
    required this.selected,
    required this.onToggle,
  });

  final List<Library> libraries;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: libraries.isEmpty
          ? Text(
              'No libraries found.  Create one from the Library screen '
              'to use this restriction.',
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textDim),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selected.length} of ${libraries.length} '
                  '${libraries.length == 1 ? 'library' : 'libraries'} '
                  'allowed',
                  style: AppTypography.captionV2
                      .copyWith(color: AppColors.textDim),
                ),
                const SizedBox(height: AppSpacing.s8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: libraries.map((lib) {
                    final isSel = selected.contains(lib.id);
                    return GestureDetector(
                      onTap: () => onToggle(lib.id),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSel
                                ? const Color(0x2EA855F7)
                                : const Color(0x08FFFFFF),
                            border: Border.all(
                              color: isSel
                                  ? const Color(0x80A855F7)
                                  : const Color(0x0FFFFFFF),
                            ),
                            borderRadius:
                                BorderRadius.circular(AppRadii.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isSel
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                size: 12,
                                color: isSel
                                    ? AppColors.violetSoft
                                    : AppColors.textMutedV2,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                lib.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isSel
                                      ? AppColors.violetSoft
                                      : AppColors.textMutedV2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
    );
  }
}

// ── AdvisoryFieldsSection ──────────────────────────────────────────────────

/// Bandwidth cap + max rating placeholders.  Both fields exist in the
/// server schema (`group_restrictions.bandwidth_cap_mbps`,
/// `group_restrictions.max_rating`) but neither is enforced — see
/// `docs/10_planning/12_groups_remediation_plan.md` §4 for why.  Rendering
/// them disabled with a tooltip is the honest UX: the operator sees the
/// surface exists without us pretending it works.
class AdvisoryFieldsSection extends StatelessWidget {
  const AdvisoryFieldsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s10),
      decoration: BoxDecoration(
        color: const Color(0x05FFFFFF),
        border: Border.all(color: const Color(0x0AFFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline,
                  size: 12, color: AppColors.textDim),
              const SizedBox(width: AppSpacing.s6),
              Expanded(
                child: Text(
                  'Advisory fields  •  recorded but not yet enforced',
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textDim,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),
          Tooltip(
            message:
                'Bandwidth cap is recorded but not enforced in v1.  See '
                'docs/10_planning/12_groups_remediation_plan.md §4.1.',
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Bandwidth cap (Mbps)',
                hintText: '—',
                border: const OutlineInputBorder(),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.textDim.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s8),
          Tooltip(
            message:
                'Max rating is recorded but not enforced in v1 — '
                'media_files has no rating column yet.  See '
                'docs/10_planning/12_groups_remediation_plan.md §4.2.',
            child: TextField(
              enabled: false,
              decoration: InputDecoration(
                isDense: true,
                labelText: 'Max content rating',
                hintText: '—',
                border: const OutlineInputBorder(),
                disabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: AppColors.textDim.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── AddMemberDialog ────────────────────────────────────────────────────────

/// Real client picker for adding members.  Replaces the earlier raw-UUID
/// `TextField` that asked operators to paste client ids by hand.
///
/// On open: fetches the operator's paired clients via `ClientsRepository`,
/// filters to approved + trusted (so pending pair requests + revoked
/// clients don't pollute the picker), and excludes any client already in
/// the group.  Multi-select; Confirm fires `onConfirm(clientIds)`.
class AddMemberDialog extends StatefulWidget {
  const AddMemberDialog({
    super.key,
    required this.groupName,
    required this.existingMemberIds,
    required this.onConfirm,
  });

  final String groupName;
  final Set<String> existingMemberIds;
  final void Function(List<String> clientIds) onConfirm;

  @override
  State<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<AddMemberDialog> {
  static final _log = Logger();

  bool _loading = true;
  String? _error;
  List<ClientListItem> _clients = const [];
  final Set<String> _selected = <String>{};
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = GetIt.I<ClientsRepository>();
      final all = await repo.getClients();
      if (!mounted) return;
      setState(() {
        _clients = all;
        _loading = false;
      });
    } catch (e, st) {
      _log.w('Add-member client list load failed',
          error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load clients: $e';
        _loading = false;
      });
    }
  }

  /// Eligible candidates: approved + trusted, not already in the group,
  /// matching the optional search term.  Search hits both name and id so
  /// an operator who really does want to paste a known UUID can still do
  /// so — but they no longer have to.
  List<ClientListItem> get _filtered {
    final s = _search.trim().toLowerCase();
    return _clients.where((c) {
      if (c.status != ClientStatus.approved) return false;
      if (!c.isTrusted) return false;
      if (widget.existingMemberIds.contains(c.id)) return false;
      if (s.isEmpty) return true;
      return c.name.toLowerCase().contains(s) ||
          c.id.toLowerCase().contains(s);
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  void _toggle(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final canConfirm = !_loading && _selected.isNotEmpty;
    return FluxGlassDialog(
      title: Text('Add members to ${widget.groupName}'),
      content: SizedBox(
        width: 460,
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pick one or more paired devices.  Pending pair requests + '
              'revoked clients are excluded.',
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textDim),
            ),
            const SizedBox(height: AppSpacing.s12),

            // Search box — filters by name OR raw id (the latter for
            // operators who paste UUIDs from external tooling).
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search_rounded, size: 16),
                hintText: 'Search by name or id',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: AppSpacing.s10),

            // Selection counter — operator wants to know "did the click
            // register" without scrolling the list.
            Row(
              children: [
                Text(
                  _loading
                      ? 'Loading clients…'
                      : '${_selected.length} selected  ·  '
                          '${filtered.length} available',
                  style: AppTypography.captionV2
                      .copyWith(color: AppColors.textDim),
                ),
                const Spacer(),
                if (_selected.isNotEmpty && !_loading)
                  GestureDetector(
                    onTap: () => setState(_selected.clear),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        'Clear',
                        style: AppTypography.captionV2.copyWith(
                          color: AppColors.violet,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.s8),

            // Body — loading / error / empty / list.
            Expanded(child: _buildBody(filtered)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
          onPressed: canConfirm
              ? () {
                  widget.onConfirm(_selected.toList());
                  Navigator.pop(context);
                }
              : null,
          child: Text(
            _selected.isEmpty
                ? 'Add'
                : 'Add ${_selected.length} '
                    '${_selected.length == 1 ? "device" : "devices"}',
          ),
        ),
      ],
    );
  }

  Widget _buildBody(List<ClientListItem> filtered) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.violet,
          ),
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 18, color: AppColors.red),
            const SizedBox(height: AppSpacing.s8),
            Text(
              _error!,
              style:
                  AppTypography.bodySmall.copyWith(color: AppColors.textBody),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.s10),
            FluxButton(
              variant: FluxButtonVariant.secondary,
              size: FluxButtonSize.sm,
              icon: Icons.refresh_rounded,
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _load();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (filtered.isEmpty) {
      // Two distinct empty states: "no clients at all" vs "all eligible
      // clients are already in the group".  Operator gets actionable
      // copy in both cases.
      final hasAnyApproved = _clients.any(
        (c) => c.status == ClientStatus.approved && c.isTrusted,
      );
      final allInGroup = hasAnyApproved &&
          _clients
              .where((c) =>
                  c.status == ClientStatus.approved && c.isTrusted)
              .every((c) => widget.existingMemberIds.contains(c.id));
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.s12),
          child: Text(
            _search.isNotEmpty
                ? 'No clients match "${_search.trim()}".'
                : allInGroup
                    ? 'Every paired device is already in this group.'
                    : 'No paired devices.  Pair one from the Clients '
                        'screen first.',
            style:
                AppTypography.captionV2.copyWith(color: AppColors.textDim),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: filtered.length,
        separatorBuilder: (_, _) => const Divider(
          height: 1,
          thickness: 1,
          color: Color(0x06FFFFFF),
        ),
        itemBuilder: (_, i) {
          final c = filtered[i];
          return _ClientPickRow(
            client: c,
            selected: _selected.contains(c.id),
            onTap: () => _toggle(c.id),
          );
        },
      ),
    );
  }
}

/// One row in the [AddMemberDialog]'s scrollable list.
class _ClientPickRow extends StatefulWidget {
  const _ClientPickRow({
    required this.client,
    required this.selected,
    required this.onTap,
  });

  final ClientListItem client;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_ClientPickRow> createState() => _ClientPickRowState();
}

class _ClientPickRowState extends State<_ClientPickRow> {
  bool _hover = false;

  IconData get _platformIcon => switch (widget.client.platform) {
        ClientPlatform.android => Icons.phone_android,
        ClientPlatform.ios => Icons.phone_iphone,
        ClientPlatform.windows => Icons.desktop_windows_outlined,
        ClientPlatform.macos => Icons.desktop_mac_outlined,
        ClientPlatform.linux => Icons.computer_outlined,
      };

  String get _platformLabel => switch (widget.client.platform) {
        ClientPlatform.android => 'Android',
        ClientPlatform.ios => 'iOS',
        ClientPlatform.windows => 'Windows',
        ClientPlatform.macos => 'macOS',
        ClientPlatform.linux => 'Linux',
      };

  String _relativeTime(DateTime dt) {
    final delta = DateTime.now().toUtc().difference(dt.toUtc());
    if (delta.inSeconds < 30) return 'Just now';
    if (delta.inMinutes < 1) return '${delta.inSeconds}s ago';
    if (delta.inMinutes < 60) return '${delta.inMinutes}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays < 7) return '${delta.inDays}d ago';
    return '${delta.inDays ~/ 7}w ago';
  }

  void _setHover(bool value) {
    if (!mounted) return;
    setState(() => _hover = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.client;
    final bg = widget.selected
        ? const Color(0x14A855F7)
        : (_hover ? const Color(0x06FFFFFF) : Colors.transparent);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.s12,
            vertical: AppSpacing.s10,
          ),
          color: bg,
          child: Row(
            children: [
              // Selection indicator — boxy 14×14 outline matching the
              // glass dialog aesthetic.
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: widget.selected
                      ? AppColors.violet
                      : Colors.transparent,
                  border: Border.all(
                    color: widget.selected
                        ? AppColors.violet
                        : AppColors.textDim,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: widget.selected
                    ? const Icon(Icons.check_rounded,
                        size: 10, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: AppSpacing.s10),
              Icon(_platformIcon, size: 14, color: AppColors.violet),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textBright,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$_platformLabel  ·  '
                      'last seen ${_relativeTime(c.lastSeen)}',
                      style: AppTypography.captionV2
                          .copyWith(color: AppColors.textDim),
                    ),
                  ],
                ),
              ),
              if (c.lastIp != null) ...[
                const SizedBox(width: AppSpacing.s8),
                Text(
                  c.lastIp!,
                  style: AppTypography.captionV2.copyWith(
                    color: AppColors.textMutedV2,
                    fontFamily: 'JetBrainsMono',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── PinSection ─────────────────────────────────────────────────────────────

/// PIN editor section.  M4 + M8 of `13_groups_v2_content_spaces.md`.
/// Surfaces the shared/per-client model picker, the PIN field with strength
/// validation, the session/per-entry mode picker, and the mode-switch
/// banner that previews server validation rules before save.
class PinSection extends StatefulWidget {
  const PinSection({
    super.key,
    required this.groupRequiresPin,
    required this.groupPinMode,
    required this.groupPinModel,
    required this.pinUpdate,
    required this.pinModeUpdate,
    required this.pinModelUpdate,
    required this.onPinChanged,
    required this.onPinModeChanged,
    required this.onPinModelChanged,
  });

  final bool groupRequiresPin;
  final PinMode groupPinMode;
  final PinModel groupPinModel;
  final String? pinUpdate;
  final PinMode? pinModeUpdate;
  final PinModel? pinModelUpdate;
  final ValueChanged<String?> onPinChanged;
  final ValueChanged<PinMode?> onPinModeChanged;
  final ValueChanged<PinModel?> onPinModelChanged;

  /// Effective model — operator-selected `pinModelUpdate` if set, else
  /// the group's current `pinModel`.  Pure helper so the rest of the
  /// section can branch consistently.
  PinModel get effectiveModel => pinModelUpdate ?? groupPinModel;

  @override
  State<PinSection> createState() => _PinSectionState();
}

class _PinSectionState extends State<PinSection> {
  final _pinCtrl = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  /// Mirror the server's `_OBVIOUS_PINS` blocklist for snappy client-side
  /// feedback.  Server is authoritative; this just stops obvious 1234 /
  /// 0000 attempts before the network round-trip.
  static const _obviousPins = {
    '0000', '1111', '2222', '3333', '4444', '5555', '6666', '7777',
    '8888', '9999',
    '1234', '2345', '3456', '4567', '5678', '6789',
    '4321', '5432', '6543', '7654', '8765', '9876', '0987',
    '0123',
    '2580',
  };

  String? _validate(String pin) {
    if (pin.isEmpty) return null; // means "remove PIN" — handled separately
    if (!RegExp(r'^[0-9]+$').hasMatch(pin)) return 'PIN must be numeric';
    if (pin.length < 4 || pin.length > 8) {
      return 'PIN must be 4-8 digits';
    }
    if (_obviousPins.contains(pin)) {
      return 'PIN is too obvious — try something less guessable';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.effectiveModel;
    final isPerClient = model == PinModel.perClient;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s12),
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded,
                  size: 14, color: AppColors.textMutedV2),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'PIN protection',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (widget.groupRequiresPin && widget.pinUpdate != '')
                const FluxChip(
                  'Required',
                  color: FluxChipColor.purple,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.s8),

          // M8 — model picker.  Always visible so the operator can
          // create a per-client group (no shared PIN at create time)
          // or flip an existing group's mode.  Switching modes mid-edit
          // has documented consequences (per §M8c of the v2 plan): the
          // edit-state owner clears `pinUpdate` when switching to
          // per-client; switching to shared without a fresh PIN is
          // rejected by the server with a 400.
          SegmentedButton<PinModel>(
            segments: const [
              ButtonSegment<PinModel>(
                value: PinModel.shared,
                label: Text('Shared PIN'),
                icon: Icon(Icons.group_rounded, size: 14),
              ),
              ButtonSegment<PinModel>(
                value: PinModel.perClient,
                label: Text('Per-client PIN'),
                icon: Icon(Icons.smartphone_rounded, size: 14),
              ),
            ],
            selected: {model},
            onSelectionChanged: (s) => widget.onPinModelChanged(s.first),
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              textStyle: AppTypography.captionV2,
            ),
          ),
          const SizedBox(height: AppSpacing.s8),

          Text(
            isPerClient
                ? 'Each member device sets its own PIN on first access. '
                    'Operator never sees the PINs; you can clear an '
                    'individual member\'s PIN from the Members tab to '
                    'force them to re-enroll.'
                : (widget.groupRequiresPin
                    ? 'Members must enter the PIN to see this group\'s '
                        'libraries.  Setting a new PIN clears existing '
                        'unlocks — every member device re-PINs on next '
                        'access.'
                    : 'Optional: require a PIN to enter this group.  '
                        'Useful for adult / sensitive content on a '
                        'shared device.'),
            style: AppTypography.captionV2
                .copyWith(color: AppColors.textDim),
          ),

          // Mode-switch warnings — surface server-side rules in the UI
          // before the operator hits Save.
          if (widget.pinModelUpdate != null &&
              widget.pinModelUpdate != widget.groupPinModel) ...[
            const SizedBox(height: AppSpacing.s8),
            _buildModeSwitchBanner(),
          ],

          const SizedBox(height: AppSpacing.s10),
          // Per-client mode hides the shared-PIN edit affordances —
          // there's no household secret to set, change, or remove.
          if (!isPerClient)
            (_editing ? _buildEditing() : _buildIdle()),
        ],
      ),
    );
  }

  /// Banner shown when the operator has flipped the model picker but
  /// not yet saved.  Mirrors the server-side validation rules so the
  /// operator isn't surprised by a 400 on Save.
  Widget _buildModeSwitchBanner() {
    final flippingToShared = widget.pinModelUpdate == PinModel.shared;
    final missingNewPin = flippingToShared &&
        (widget.pinUpdate == null || widget.pinUpdate!.isEmpty);
    final color = missingNewPin ? AppColors.amber : AppColors.violet;
    final icon = missingNewPin
        ? Icons.warning_amber_rounded
        : Icons.swap_horiz_rounded;
    final text = flippingToShared
        ? (missingNewPin
            ? 'Switching to shared mode requires a new household PIN. '
                'Use "Set PIN" below before saving.'
            : 'Switching to shared mode — every member\'s per-client '
                'PIN will be cleared and replaced by the new shared PIN.')
        : 'Switching to per-client mode — the shared PIN will be '
            'removed.  Each member sets their own on next access.';
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.captionV2
                .copyWith(color: AppColors.textBody),
          ),
        ),
      ],
    );
  }

  Widget _buildIdle() {
    if (widget.pinUpdate == '') {
      // Pending removal — show a banner with Undo.
      return Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 14, color: AppColors.amber),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              'PIN will be removed on save.',
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textBody),
            ),
          ),
          FluxButton(
            variant: FluxButtonVariant.ghost,
            size: FluxButtonSize.sm,
            onPressed: () => widget.onPinChanged(null),
            child: const Text('Undo'),
          ),
        ],
      );
    }
    if (widget.pinUpdate != null && widget.pinUpdate!.isNotEmpty) {
      // Pending set — operator already typed a new PIN, which means we
      // collapsed back from editing.  Show a "PIN will be set on save"
      // banner with Edit + Cancel.
      return Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 14, color: AppColors.violet),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              widget.groupRequiresPin
                  ? 'PIN will be changed on save.'
                  : 'PIN will be set on save.',
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textBody),
            ),
          ),
          FluxButton(
            variant: FluxButtonVariant.ghost,
            size: FluxButtonSize.sm,
            onPressed: () {
              setState(() {
                _pinCtrl.text = widget.pinUpdate ?? '';
                _editing = true;
              });
            },
            child: const Text('Edit'),
          ),
          FluxButton(
            variant: FluxButtonVariant.ghost,
            size: FluxButtonSize.sm,
            onPressed: () => widget.onPinChanged(null),
            child: const Text('Cancel'),
          ),
        ],
      );
    }
    // No pending change — show action buttons depending on current state.
    return Row(
      children: [
        if (!widget.groupRequiresPin)
          FluxButton(
            variant: FluxButtonVariant.outline,
            size: FluxButtonSize.sm,
            icon: Icons.lock_outline_rounded,
            onPressed: () => setState(() {
              _pinCtrl.clear();
              _editing = true;
            }),
            child: const Text('Set PIN'),
          )
        else ...[
          FluxButton(
            variant: FluxButtonVariant.outline,
            size: FluxButtonSize.sm,
            icon: Icons.lock_reset_rounded,
            onPressed: () => setState(() {
              _pinCtrl.clear();
              _editing = true;
            }),
            child: const Text('Change PIN'),
          ),
          const SizedBox(width: AppSpacing.s8),
          FluxButton(
            variant: FluxButtonVariant.danger,
            size: FluxButtonSize.sm,
            icon: Icons.lock_open_rounded,
            onPressed: () => widget.onPinChanged(''),
            child: const Text('Remove PIN'),
          ),
        ],
      ],
    );
  }

  Widget _buildEditing() {
    final err = _validate(_pinCtrl.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _pinCtrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'PIN (4-8 digits)',
            errorText: _pinCtrl.text.isEmpty ? null : err,
            border: const OutlineInputBorder(),
            counterText: '',
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        // PIN mode picker — `session` (12 h) is the practical default;
        // `per-entry` (5 min, refreshes on activity) for sensitive content
        // where every navigation should re-PIN.
        Row(
          children: [
            Text(
              'Mode',
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textDim),
            ),
            const SizedBox(width: AppSpacing.s10),
            Expanded(
              child: SegmentedButton<PinMode>(
                segments: const [
                  ButtonSegment<PinMode>(
                    value: PinMode.session,
                    label: Text('Session  ·  12 h'),
                  ),
                  ButtonSegment<PinMode>(
                    value: PinMode.perEntry,
                    label: Text('Per-entry  ·  5 min'),
                  ),
                ],
                selected: {
                  widget.pinModeUpdate ?? widget.groupPinMode,
                },
                onSelectionChanged: (s) =>
                    widget.onPinModeChanged(s.first),
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  textStyle: AppTypography.captionV2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s10),
        Row(
          children: [
            FluxButton(
              variant: FluxButtonVariant.outline,
              size: FluxButtonSize.sm,
              onPressed: () => setState(() {
                _pinCtrl.clear();
                _editing = false;
                widget.onPinChanged(null);
              }),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: AppSpacing.s8),
            FluxButton(
              variant: FluxButtonVariant.primary,
              size: FluxButtonSize.sm,
              onPressed: err != null || _pinCtrl.text.isEmpty
                  ? null
                  : () {
                      widget.onPinChanged(_pinCtrl.text);
                      setState(() => _editing = false);
                    },
              child: const Text('Apply'),
            ),
          ],
        ),
      ],
    );
  }
}
