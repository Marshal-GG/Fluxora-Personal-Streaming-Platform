/// Dedicated group create / edit page.
///
/// Plan: `docs/10_planning/14_groups_management_page.md`.  Replaces the
/// `_CreateGroupDialog` + `_EditGroupDialog` modal pair with a 6-tab
/// page (Overview / Members / Access / PIN / Activity / View As).
///
/// M1 scope (this file): page shell + routing + 6 placeholder tabs.
/// No save logic yet; existing modal still in use on the list page so
/// operators retain a working flow during the transition.  M2 lands
/// the Overview save flow and modal retirement comes at M4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/group.dart';
import 'package:fluxora_core/network/api_client.dart';
import 'package:fluxora_core/network/endpoints.dart';
import 'package:fluxora_core/widgets/flux_button.dart';
import 'package:fluxora_core/widgets/flux_chip.dart';
import 'package:fluxora_desktop/core/router/app_router.dart';
import 'package:fluxora_desktop/features/groups/domain/repositories/groups_repository.dart';
import 'package:fluxora_desktop/features/groups/presentation/cubit/groups_cubit.dart';
import 'package:fluxora_desktop/features/groups/presentation/cubit/groups_state.dart';
import 'package:fluxora_desktop/features/groups/presentation/widgets/group_form_widgets.dart';
import 'package:fluxora_desktop/features/library/domain/repositories/library_repository.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_dialog.dart';
import 'package:fluxora_desktop/shared/widgets/flux_switch.dart';
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';

// ── Tab IDs ────────────────────────────────────────────────────────────────
//
// Strings rather than enum so the URL fragment can carry them later if we
// decide to deep-link to a tab (e.g. `/groups/:id/edit#members`).  Keeps
// the door open without committing to it now.

const _kTabOverview = 'overview';
const _kTabMembers = 'members';
const _kTabAccess = 'access';
const _kTabPin = 'pin';
const _kTabActivity = 'activity';
const _kTabViewAs = 'view-as';

// ── Entry point ────────────────────────────────────────────────────────────

/// Page mode — drives copy + tab visibility (Members / Activity / View As
/// are hidden in create until first save lands an id).
enum GroupEditMode { create, edit }

class GroupEditScreen extends StatelessWidget {
  /// Edit mode — `id` is the existing group's primary key.
  const GroupEditScreen.edit({super.key, required String id})
      : _mode = GroupEditMode.edit,
        _groupId = id;

  /// Create mode — no id; first save mints one and the router replaces
  /// the URL with `/groups/:newId/edit`.
  const GroupEditScreen.create({super.key})
      : _mode = GroupEditMode.create,
        _groupId = null;

  final GroupEditMode _mode;
  final String? _groupId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GroupsCubit>(
      create: (_) => GroupsCubit(
        repository: GetIt.I<GroupsRepository>(),
        libraryRepository: GetIt.I<LibraryRepository>(),
      )..load(),
      child: _GroupEditView(mode: _mode, groupId: _groupId),
    );
  }
}

// ── View ───────────────────────────────────────────────────────────────────

class _GroupEditView extends StatefulWidget {
  const _GroupEditView({required this.mode, required this.groupId});

  final GroupEditMode mode;
  final String? groupId;

  @override
  State<_GroupEditView> createState() => _GroupEditViewState();
}

class _GroupEditViewState extends State<_GroupEditView> {
  String _activeTab = _kTabOverview;

  /// Has the cubit been told to focus the target group yet?  We do it once
  /// per page mount to avoid clobbering the user's selection on every
  /// rebuild.
  bool _selected = false;

  /// Has the seed-from-server pass run yet?  We hydrate the Overview-tab
  /// controllers from the loaded group exactly once — re-seeding on every
  /// rebuild would clobber operator edits the moment a poll tick lands.
  bool _hydrated = false;

  /// Has the page asked the cubit for pin_state-enriched members yet?
  /// One-shot per page mount — the cubit's `loadMembers` default omits
  /// the enrichment, and we don't want to re-trigger it on every state
  /// emission.  Member mutations (remove / clear PIN) call `loadMembers`
  /// directly with the enrichment so the badges stay current.
  bool _pinStateLoaded = false;

  /// Captured at create-time so the listener can match the freshly-minted
  /// group by name when the cubit's post-create `load()` arrives.  Cleared
  /// once we navigate to the new edit URL so we don't loop.
  String? _lastCreateName;

  // ── Editor scratch state ───────────────────────────────────────────────
  //
  // Controllers + scratch fields live on the page state (not in a tab
  // widget) so switching tabs keeps the operator's in-flight edits.

  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  /// Active-status scratch (group.status mirror).  null until first hydrate.
  GroupStatus? _statusEdit;

  /// Initial values captured at hydrate time so we can compute dirty
  /// without storing diffs everywhere.  Strings are trimmed before
  /// comparison so a trailing-space "edit" doesn't enable Save.
  String _initialName = '';
  String _initialDesc = '';
  GroupStatus _initialStatus = GroupStatus.active;

  // Access tab — restrictions scratch.  null = no restrictions; a value
  // means at least one toggle is on.  Tracked separately from
  // `_restrictionsDirty` because comparing GroupRestrictions equality
  // requires walking nested fields; the flag is faster + cheap to flip
  // when the form fires onChanged.
  GroupRestrictions? _restrictionsEdit;
  bool _restrictionsDirty = false;

  // M7 Tier-2 — visual identity (Overview tab) + per-group concurrent
  // stream cap (Access tab).  All three columns already exist on
  // `groups` from migration 025; UI just lights them up.  Icon + color
  // use _initial* baselines for diff-based dirty (consistent with
  // name/desc/status); cap uses a flag because comparing an int? for
  // "did the operator clear it" against the initial value would
  // misfire when the operator types and re-clears.
  String? _iconEdit;
  String? _colorEdit;
  String? _initialIcon;
  String? _initialColor;
  int? _maxConcurrentStreamsEdit;
  bool _maxConcurrentStreamsDirty = false;

  // PIN tab — same null/empty/digits semantic as the modal era:
  //   null    → leave PIN unchanged
  //   ""      → remove PIN (group becomes non-gated)
  //   digits  → set / change PIN
  String? _pinUpdate;
  PinMode? _pinModeUpdate;
  PinModel? _pinModelUpdate;

  bool _saving = false;

  bool get _dirty {
    if (widget.mode == GroupEditMode.create) {
      // In create mode, any non-empty name counts as a dirty form so the
      // Create button enables.  Description is optional; status defaults
      // to Active.  Restrictions / PIN / icon / color / cap can also be
      // set at create time and count toward dirtiness.
      return _nameCtrl.text.trim().isNotEmpty ||
          _restrictionsDirty ||
          _pinUpdate != null ||
          _pinModelUpdate != null ||
          _iconEdit != null ||
          _colorEdit != null ||
          _maxConcurrentStreamsDirty;
    }
    if (!_hydrated) return false;
    return _nameCtrl.text.trim() != _initialName ||
        _descCtrl.text.trim() != _initialDesc ||
        (_statusEdit ?? _initialStatus) != _initialStatus ||
        _restrictionsDirty ||
        _pinUpdate != null ||
        _pinModeUpdate != null ||
        _pinModelUpdate != null ||
        _iconEdit != _initialIcon ||
        _colorEdit != _initialColor ||
        _maxConcurrentStreamsDirty;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onFieldChanged);
    _descCtrl.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    // setState is cheap here; the build method re-reads `_dirty` to
    // toggle the Save button.  Throttling isn't worth the complexity.
    if (mounted) setState(() {});
  }

  /// Resolve the page's target group from the cubit state.  Edit mode
  /// looks up by id; create mode returns null.  Decoupled from the
  /// cubit's `selectedGroup` because `load()` resets that to
  /// `groups.first` after every refresh — which would silently swap
  /// the page's content to a different group post-save.
  Group? _resolveTargetGroup(GroupsLoaded state) {
    if (widget.mode == GroupEditMode.create) return null;
    final id = widget.groupId;
    if (id == null) return null;
    final matches = state.groups.where((g) => g.id == id);
    return matches.isEmpty ? null : matches.first;
  }

  /// First time the loaded group arrives, seed the controllers from it.
  /// Only runs in edit mode — create starts blank.
  void _hydrateFrom(Group group) {
    if (_hydrated) return;
    _initialName = group.name;
    _initialDesc = group.description ?? '';
    _initialStatus = group.status;
    _nameCtrl.text = _initialName;
    _descCtrl.text = _initialDesc;
    _statusEdit = group.status;
    _restrictionsEdit = group.restrictions;
    _initialIcon = group.icon;
    _initialColor = group.color;
    _iconEdit = group.icon;
    _colorEdit = group.color;
    _maxConcurrentStreamsEdit = group.maxConcurrentStreams;
    _hydrated = true;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupsCubit, GroupsState>(
      listener: (context, state) {
        if (state is! GroupsLoaded) return;

        // Auto-select the target group exactly once after the first
        // load — keeps the cubit's `selectedGroup` in sync with the URL.
        if (!_selected &&
            widget.mode == GroupEditMode.edit &&
            widget.groupId != null) {
          final target = state.groups.where((g) => g.id == widget.groupId);
          if (target.isNotEmpty) {
            context.read<GroupsCubit>().selectGroup(target.first);
            _selected = true;
          }
        }

        // Hydrate the Overview-tab editors from the loaded group exactly
        // once.  Subsequent rebuilds (poll ticks, member changes) do NOT
        // re-seed — operator's in-flight edits stick.
        final target = _resolveTargetGroup(state);
        if (!_hydrated &&
            widget.mode == GroupEditMode.edit &&
            target != null) {
          _hydrateFrom(target);
        }

        // M3: refresh members with pin_state enrichment whenever we
        // settle on a target group with PIN gating.  The cubit's default
        // `loadMembers` (called from `selectGroup` on first focus) omits
        // the enrichment; we request it once the page knows the group's
        // pin_model.
        if (!_pinStateLoaded &&
            target != null &&
            target.requiresPin &&
            !state.membersLoading) {
          _pinStateLoaded = true;
          context
              .read<GroupsCubit>()
              .loadMembers(target.id, includePinState: true);
        }

        // Detect "we just landed in create mode and the cubit's `groups`
        // grew by one" so we can navigate to the new id's edit page.  The
        // cubit's `createGroup` calls `load()` post-create, so the new row
        // arrives via this listener rather than a return value.
        if (widget.mode == GroupEditMode.create &&
            _saving &&
            _lastCreateName != null) {
          final freshlyMinted = state.groups
              .where((g) => g.name == _lastCreateName);
          if (freshlyMinted.isNotEmpty) {
            final id = freshlyMinted.first.id;
            _saving = false;
            _lastCreateName = null;
            // Replace, not push — operator's history shouldn't carry the
            // /groups/new entry once they've successfully created.
            context.go(Routes.groupEdit(id));
          }
        }
      },
      builder: (context, state) {
        return Container(
          color: AppColors.bgRoot,
          child: switch (state) {
            GroupsInitial() || GroupsLoading() => const _LoadingShell(),
            GroupsFailure(:final message) =>
              _FailureShell(message: message),
            GroupsLoaded() => _buildLoaded(
                context,
                state,
                _resolveTargetGroup(state),
              ),
          },
        );
      },
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    GroupsLoaded state,
    Group? group,
  ) {
    // Edit mode + cubit loaded but the requested id isn't in the list →
    // group was deleted between page mount and now (or someone deep-linked
    // a stale id).  N3 from §9.1 of the plan.
    if (widget.mode == GroupEditMode.edit &&
        widget.groupId != null &&
        group?.id != widget.groupId) {
      return _MissingShell(requestedId: widget.groupId!);
    }

    final isCreate = widget.mode == GroupEditMode.create;
    final title = isCreate
        ? 'New group'
        : (group?.name ?? 'Edit group');
    final isPublic = group?.isPublic ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s28),
          child: PageHeader(
            title: title,
            subtitle: _subtitleFor(_activeTab, isCreate),
            onBack: () => _onBack(context),
            actions: _HeaderActions(
              dirty: _dirty,
              saving: _saving,
              isCreate: isCreate,
              onSave: () => _onSave(context),
              onDiscard: () => _onDiscardOrBack(context),
              statusActive:
                  (_statusEdit ?? group?.status) == GroupStatus.active,
              isPublic: isPublic,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.s28,
            0,
            AppSpacing.s28,
            0,
          ),
          child: FluxTabBar(
            tabs: _tabsFor(isCreate),
            activeId: _activeTab,
            onChange: (id) => setState(() => _activeTab = id),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.s28,
              AppSpacing.s14,
              AppSpacing.s28,
              AppSpacing.s28,
            ),
            child: _buildTabBody(context, state, group),
          ),
        ),
      ],
    );
  }

  /// Tabs visible per mode.  Per §4.2 of the plan: Members / Activity /
  /// View As are hidden in create until the first save lands an id —
  /// nothing to show without a group row to anchor them to.
  List<FluxTab> _tabsFor(bool isCreate) {
    return [
      const FluxTab(
        id: _kTabOverview,
        label: 'Overview',
        icon: Icons.tune_rounded,
      ),
      if (!isCreate)
        const FluxTab(
          id: _kTabMembers,
          label: 'Members',
          icon: Icons.people_alt_outlined,
        ),
      const FluxTab(
        id: _kTabAccess,
        label: 'Access',
        icon: Icons.folder_outlined,
      ),
      const FluxTab(
        id: _kTabPin,
        label: 'PIN',
        icon: Icons.lock_outline_rounded,
      ),
      if (!isCreate)
        const FluxTab(
          id: _kTabActivity,
          label: 'Activity',
          icon: Icons.timeline_outlined,
        ),
      if (!isCreate)
        const FluxTab(
          id: _kTabViewAs,
          label: 'View as',
          icon: Icons.visibility_outlined,
        ),
    ];
  }

  String? _subtitleFor(String tab, bool isCreate) {
    if (isCreate) return 'Configure a new group before saving';
    return switch (tab) {
      _kTabOverview => 'Identity, status, and danger zone',
      _kTabMembers => 'Devices in this group + per-client PIN status',
      _kTabAccess => 'Libraries and time windows this group exposes',
      _kTabPin => 'PIN gate configuration',
      _kTabActivity => 'Recent activity scoped to this group',
      _kTabViewAs => 'Preview what a target client sees',
      _ => null,
    };
  }

  Widget _buildTabBody(
    BuildContext context,
    GroupsLoaded state,
    Group? group,
  ) {
    return switch (_activeTab) {
      _kTabOverview => _OverviewTab(
          isCreate: widget.mode == GroupEditMode.create,
          isPublic: group?.isPublic ?? false,
          group: group,
          memberCount: state.members.length,
          nameCtrl: _nameCtrl,
          descCtrl: _descCtrl,
          status: _statusEdit ?? GroupStatus.active,
          onStatusChanged: (s) => setState(() => _statusEdit = s),
          icon: _iconEdit,
          color: _colorEdit,
          onIconChanged: (i) => setState(() => _iconEdit = i),
          onColorChanged: (c) => setState(() => _colorEdit = c),
        ),
      _kTabMembers => _MembersTab(
          group: group,
          members: state.members,
          membersLoading: state.membersLoading,
        ),
      _kTabAccess => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GroupRestrictionsForm(
              libraries: state.libraries,
              initial: _restrictionsEdit,
              onChanged: (r) {
                // Only flag dirty when something actually changed from
                // initial; the form fires onChanged on first emit too.
                setState(() {
                  _restrictionsEdit = r;
                  _restrictionsDirty = true;
                });
              },
            ),
            const SizedBox(height: AppSpacing.s18),
            _ConcurrentStreamsField(
              value: _maxConcurrentStreamsEdit,
              onChanged: (v) => setState(() {
                _maxConcurrentStreamsEdit = v;
                _maxConcurrentStreamsDirty = true;
              }),
            ),
          ],
        ),
      _kTabPin => PinSection(
          groupRequiresPin: group?.requiresPin ?? false,
          groupPinMode: group?.pinMode ?? PinMode.session,
          groupPinModel: group?.pinModel ?? PinModel.shared,
          pinUpdate: _pinUpdate,
          pinModeUpdate: _pinModeUpdate,
          pinModelUpdate: _pinModelUpdate,
          onPinChanged: (v) => setState(() => _pinUpdate = v),
          onPinModeChanged: (m) => setState(() => _pinModeUpdate = m),
          onPinModelChanged: (m) => setState(() {
            _pinModelUpdate = m;
            // Switching TO per-client clears any pending shared-PIN
            // edit — there's no shared secret to set.
            if (m == PinModel.perClient) {
              _pinUpdate = null;
            }
          }),
        ),
      _kTabActivity => _ActivityTab(groupId: group?.id ?? ''),
      _kTabViewAs => _ViewAsTab(
          groupMembers: state.members,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  /// Back-arrow handler — same path as Discard.  Both confirm if the
  /// page is dirty so the operator doesn't lose typing on accidental
  /// navigation.
  Future<void> _onBack(BuildContext context) => _onDiscardOrBack(context);

  Future<void> _onDiscardOrBack(BuildContext context) async {
    if (_saving) return; // can't navigate away mid-save
    if (_dirty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => FluxGlassDialog(
          title: const Text('Discard changes?'),
          content: const Text(
            'You have unsaved changes on this page.  Leaving now drops them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.red),
              onPressed: () => Navigator.pop(dialogCtx, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!context.mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.groups);
    }
  }

  Future<void> _onSave(BuildContext context) async {
    if (!_dirty || _saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final desc = _descCtrl.text.trim();
    final descToSend = desc.isEmpty ? null : desc;
    final cubit = context.read<GroupsCubit>();

    setState(() => _saving = true);

    // Per-client groups never carry a shared PIN at create time; collapse
    // any stray "" or non-empty value to null.
    final isPerClient = _pinModelUpdate == PinModel.perClient;
    String? pinForSend;
    if (widget.mode == GroupEditMode.create) {
      pinForSend = (isPerClient || (_pinUpdate?.isEmpty ?? true))
          ? null
          : _pinUpdate;
    } else {
      // PATCH semantic: null = leave unchanged, "" = remove, digits = set.
      pinForSend = _pinUpdate;
    }
    final pinModeForSend =
        (_pinUpdate == null && _pinModelUpdate == null) ? null : _pinModeUpdate;

    if (widget.mode == GroupEditMode.create) {
      // Capture the name BEFORE the cubit's load() callback fires so the
      // listener can match the freshly-minted row.  Two simultaneous
      // creates with the same name is operator self-harm; not handled.
      _lastCreateName = name;
      await cubit.createGroup(
        name: name,
        description: descToSend,
        restrictions: _restrictionsDirty ? _restrictionsEdit : null,
        pin: pinForSend,
        pinMode: pinModeForSend,
        pinModel: _pinModelUpdate,
        icon: _iconEdit,
        color: _colorEdit,
        maxConcurrentStreams:
            _maxConcurrentStreamsDirty ? _maxConcurrentStreamsEdit : null,
      );
      // The listener navigates to /groups/<newId>/edit when the new row
      // appears in the cubit's groups list.  If creation failed, the
      // cubit emits GroupsFailure and we fall through to the snackbar.
    } else {
      await cubit.updateGroup(
        widget.groupId!,
        name: name == _initialName ? null : name,
        description: descToSend == null
            ? (_initialDesc.isEmpty ? null : '')
            : (descToSend == _initialDesc ? null : descToSend),
        status: (_statusEdit ?? _initialStatus) == _initialStatus
            ? null
            : _statusEdit,
        restrictions: _restrictionsDirty ? _restrictionsEdit : null,
        pin: pinForSend,
        pinMode: pinModeForSend,
        pinModel: _pinModelUpdate,
        icon: _iconEdit == _initialIcon ? null : _iconEdit,
        color: _colorEdit == _initialColor ? null : _colorEdit,
        maxConcurrentStreams: _maxConcurrentStreamsDirty
            ? _maxConcurrentStreamsEdit
            : null,
      );
      if (!mounted) return;
      // After a successful update the cubit's `load()` repopulates the
      // groups list; reset baselines so the next edit starts clean.
      _initialName = name;
      _initialDesc = descToSend ?? '';
      _initialStatus = _statusEdit ?? _initialStatus;
      _initialIcon = _iconEdit;
      _initialColor = _colorEdit;
      _restrictionsDirty = false;
      _maxConcurrentStreamsDirty = false;
      _pinUpdate = null;
      _pinModeUpdate = null;
      _pinModelUpdate = null;
      setState(() => _saving = false);
      // Re-resolve the messenger from the current state's context — the
      // analyzer can't follow that `mounted` is the State guard, but
      // pulling it from `this.context` after the mounted check is safe.
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(
          content: Text('Group saved'),
          backgroundColor: AppColors.emerald,
        ),
      );
    }
  }
}

// ── Header actions ─────────────────────────────────────────────────────────

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.dirty,
    required this.saving,
    required this.isCreate,
    required this.onSave,
    required this.onDiscard,
    required this.statusActive,
    required this.isPublic,
  });

  final bool dirty;
  final bool saving;
  final bool isCreate;
  final VoidCallback onSave;
  final VoidCallback onDiscard;
  final bool statusActive;
  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Status pill — visual cue mirroring the list-page chip so the
        // operator sees at a glance whether the group is active without
        // visiting the Overview tab.
        if (!isCreate)
          FluxChip(
            statusActive ? 'Active' : 'Inactive',
            color: statusActive
                ? FluxChipColor.purple
                : FluxChipColor.neutral,
          ),
        if (!isCreate && isPublic) ...[
          const SizedBox(width: AppSpacing.s8),
          const FluxChip('Public', color: FluxChipColor.info),
        ],
        const SizedBox(width: AppSpacing.s12),
        FluxButton(
          variant: FluxButtonVariant.ghost,
          onPressed: dirty && !saving ? onDiscard : null,
          child: const Text('Discard'),
        ),
        const SizedBox(width: AppSpacing.s8),
        FluxButton(
          icon: saving ? null : Icons.save_outlined,
          onPressed: dirty && !saving ? onSave : null,
          child: saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textBright,
                  ),
                )
              : Text(isCreate ? 'Create' : 'Save'),
        ),
      ],
    );
  }
}

// ── Members tab ────────────────────────────────────────────────────────────
//
// M3 of `14_groups_management_page.md`.  Lists members with enrollment +
// grant + recent-failures state surfaced via the M3 server-side
// `?include=pin_state` enrichment so we don't fan out N+1 calls.

class _MembersTab extends StatelessWidget {
  const _MembersTab({
    required this.group,
    required this.members,
    required this.membersLoading,
  });

  final Group? group;
  final List<Map<String, dynamic>> members;
  final bool membersLoading;

  void _openAddMember(BuildContext context) {
    final g = group;
    if (g == null) return;
    // Existing member ids — the dialog filters these out so we don't
    // show "add Pixel 8" when Pixel 8 is already in the group.  Loose
    // map shape covers both `client_id` and `id` keys observed in the
    // wild (the M3 server enrichment doesn't change which key is
    // present; the legacy member rows used `id`).
    final existingIds = <String>{
      for (final m in members)
        if (m['client_id'] is String) m['client_id'] as String
        else if (m['id'] is String) m['id'] as String,
    };
    final cubit = context.read<GroupsCubit>();
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AddMemberDialog(
        groupName: g.name,
        existingMemberIds: existingIds,
        onConfirm: (clientIds) async {
          await cubit.addMembers(g.id, clientIds);
          // Refresh with pin_state so the new rows render their
          // enrollment + grant badges immediately.
          await cubit.loadMembers(g.id, includePinState: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPublic = group?.isPublic ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                membersLoading && members.isEmpty
                    ? 'Members'
                    : 'Members (${members.length})',
                style: AppTypography.body.copyWith(
                  color: AppColors.textBright,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FluxButton(
              variant: FluxButtonVariant.outline,
              size: FluxButtonSize.sm,
              icon: Icons.add_rounded,
              onPressed: isPublic ? null : () => _openAddMember(context),
              child: const Text('Add member'),
            ),
          ],
        ),
        if (isPublic) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            'All paired clients are members of Public automatically.',
            style: AppTypography.captionV2.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.s12),
        if (membersLoading && members.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.violet,
                ),
              ),
            ),
          )
        else if (members.isEmpty)
          _EmptyMembersCard(isPublic: isPublic)
        else
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.s12,
              vertical: AppSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: const Color(0x06FFFFFF),
              border: Border.all(color: const Color(0x14FFFFFF)),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Column(
              children: [
                for (var i = 0; i < members.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      color: Color(0x10FFFFFF),
                    ),
                  _MembersTabRow(
                    member: members[i],
                    groupId: group?.id ?? '',
                    pinModel: group?.pinModel ?? PinModel.shared,
                    requiresPin: group?.requiresPin ?? false,
                    isPublic: isPublic,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _EmptyMembersCard extends StatelessWidget {
  const _EmptyMembersCard({required this.isPublic});

  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s24),
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Center(
        child: Text(
          isPublic
              ? 'No paired clients yet — pair a device to seed Public.'
              : 'No members yet — tap "Add member" to grant a paired '
                  'device access.',
          style: AppTypography.captionV2.copyWith(
            color: AppColors.textMutedV2,
          ),
        ),
      ),
    );
  }
}

class _MembersTabRow extends StatelessWidget {
  const _MembersTabRow({
    required this.member,
    required this.groupId,
    required this.pinModel,
    required this.requiresPin,
    required this.isPublic,
  });

  final Map<String, dynamic> member;
  final String groupId;
  final PinModel pinModel;
  final bool requiresPin;
  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    final name = member['name'] as String? ??
        member['client_name'] as String? ??
        'Unknown';
    final platform = member['platform'] as String? ?? '';
    final clientId = member['client_id'] as String? ??
        member['id'] as String? ??
        '';
    final enrollmentState = member['enrollment_state'] as String?;
    final hasGrant = member['has_active_grant'] as bool? ?? false;
    final recentFails = member['recent_failed_attempts'] as int? ?? 0;
    final isLockedOut = recentFails >= 5;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.violetDeep.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.person_outline_rounded,
                size: 16,
                color: AppColors.violetTint,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBody,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (platform.isNotEmpty)
                  Text(
                    platform,
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.textDim,
                    ),
                  ),
              ],
            ),
          ),
          // Enrollment + grant badges.  Per-client mode shows the
          // enrollment state explicitly; shared mode only surfaces the
          // grant chip when active.  Locked-out wins over both.
          if (isLockedOut) ...[
            const FluxChip(
              'Locked out',
              color: FluxChipColor.error,
            ),
            const SizedBox(width: AppSpacing.s8),
          ] else if (requiresPin && pinModel == PinModel.perClient) ...[
            FluxChip(
              enrollmentState == 'enrolled' ? 'Enrolled' : 'Not enrolled',
              color: enrollmentState == 'enrolled'
                  ? FluxChipColor.success
                  : FluxChipColor.warning,
            ),
            const SizedBox(width: AppSpacing.s8),
          ],
          if (hasGrant) ...[
            const FluxChip(
              'Unlocked',
              color: FluxChipColor.purple,
            ),
            const SizedBox(width: AppSpacing.s8),
          ],
          // Per-row actions.  Clear PIN only meaningful in per-client
          // mode; Remove disabled on Public.
          PopupMenuButton<String>(
            tooltip: 'Member actions',
            icon: const Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: AppColors.textMutedV2,
            ),
            onSelected: (value) =>
                _onAction(context, value, clientId, name),
            itemBuilder: (ctx) => [
              if (requiresPin && pinModel == PinModel.perClient)
                const PopupMenuItem<String>(
                  value: 'clear_pin',
                  child: Text('Clear PIN enrollment'),
                ),
              PopupMenuItem<String>(
                value: 'remove',
                enabled: !isPublic,
                child: Text(
                  isPublic
                      ? 'Public membership is automatic'
                      : 'Remove from group',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(
    BuildContext context,
    String action,
    String clientId,
    String name,
  ) async {
    final cubit = context.read<GroupsCubit>();
    if (action == 'remove') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => FluxGlassDialog(
          title: const Text('Remove member?'),
          content: Text(
            '$name will lose access to this group\'s libraries on next '
            'stream-start.  In-flight streams continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.red,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await cubit.removeMember(groupId, clientId);
      }
    } else if (action == 'clear_pin') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => FluxGlassDialog(
          title: const Text('Clear PIN enrollment?'),
          content: Text(
            '$name will be asked to set up a new PIN on next access to '
            'this group.  Their current grant is also dropped.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.violet,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear PIN'),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        try {
          await cubit.clearMemberPin(groupId, clientId);
        } catch (e) {
          // clearMemberPin doesn't yet exist on the cubit; fallback
          // surfaced via snackbar.  See cubit changes for M3.
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not clear PIN: $e')),
            );
          }
        }
      }
    }
  }
}

// ── Overview tab ───────────────────────────────────────────────────────────
//
// Identity (name + description) + status toggle.  The Public group locks
// down the name field and the status toggle — operator can change the
// description but not turn off Public or rename it ("Public group's name
// is fixed; you can change its description, icon, and color").  Same
// pattern as the Library type-immutable lock (ADR-016).

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.isCreate,
    required this.isPublic,
    required this.group,
    required this.memberCount,
    required this.nameCtrl,
    required this.descCtrl,
    required this.status,
    required this.onStatusChanged,
    required this.icon,
    required this.color,
    required this.onIconChanged,
    required this.onColorChanged,
  });

  final bool isCreate;
  final bool isPublic;
  final Group? group;
  final int memberCount;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final GroupStatus status;
  final ValueChanged<GroupStatus> onStatusChanged;
  final String? icon;
  final String? color;
  final ValueChanged<String?> onIconChanged;
  final ValueChanged<String?> onColorChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: nameCtrl,
          autofocus: isCreate,
          enabled: !isPublic,
          decoration: InputDecoration(
            labelText: 'Group Name',
            border: const OutlineInputBorder(),
            helperText: isPublic
                ? 'Public group\'s name is fixed.'
                : null,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        TextField(
          controller: descCtrl,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: AppSpacing.s18),

        // M7 Tier-2 — visual identity.  Icon + color drive the chip
        // prefix on the list page + a future Members-tab avatar.  Both
        // optional: leaving them null is the v2 default ("Public" uses
        // 'public' / '#94A3B8' from migration 025; user-created groups
        // start without).
        _IconPicker(
          value: icon,
          onChanged: onIconChanged,
        ),
        const SizedBox(height: AppSpacing.s12),
        _ColorPicker(
          value: color,
          onChanged: onColorChanged,
        ),
        const SizedBox(height: AppSpacing.s24),

        // Status toggle — server gate filters `WHERE g.status = 'active'`
        // so flipping inactive disables the gate immediately for new
        // streams.  In-flight streams continue (membership-mid-stream is
        // documented out-of-scope per §4.4 of 12_groups_remediation_plan).
        // Public locks this — deactivating Public would orphan every
        // paired client's baseline visibility.
        Opacity(
          opacity: isPublic ? 0.5 : 1.0,
          child: IgnorePointer(
            ignoring: isPublic,
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 14,
                  color: AppColors.textMutedV2,
                ),
                const SizedBox(width: AppSpacing.s8),
                Expanded(
                  child: Text(
                    status == GroupStatus.active
                        ? 'Active  •  restrictions enforced'
                        : 'Inactive  •  restrictions not enforced',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textBright,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                FluxSwitch(
                  value: status == GroupStatus.active,
                  onChanged: (v) => onStatusChanged(
                    v ? GroupStatus.active : GroupStatus.inactive,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isPublic) ...[
          const SizedBox(height: AppSpacing.s8),
          Text(
            'The Public group cannot be deactivated — every paired client '
            'inherits its libraries as a baseline visibility.',
            style: AppTypography.captionV2.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
        ],

        // Danger Zone — delete the group + reset all PINs.  Hidden in
        // create mode (nothing to delete yet) and on Public (deletion
        // forbidden by API).
        if (!isCreate && !isPublic && group != null) ...[
          const SizedBox(height: AppSpacing.s28),
          _DangerZoneCard(
            group: group!,
            memberCount: memberCount,
          ),
        ],
      ],
    );
  }
}

// ── Visual-identity helpers ────────────────────────────────────────────────
//
// Icon + color choices live in single source-of-truth tables so the list
// page chip + the Members-tab avatar can render the same picks the
// operator made on the Overview tab.  `kGroupIconChoices` and
// `kGroupColorChoices` are public so the list-page detail panel can
// look up the IconData / Color for a given key without re-implementing
// the lookup.

/// 12-icon set for group visual identity (M7 Tier-2 of
/// `13_groups_v2_content_spaces.md`).  Keys persist to
/// `groups.icon TEXT` (migration 025); rendering happens via
/// [groupIconData] which falls back to `Icons.group_rounded` for
/// unknown keys so older data still renders.
const Map<String, IconData> kGroupIconChoices = <String, IconData>{
  'home': Icons.home_rounded,
  'kids': Icons.child_care_rounded,
  'lock': Icons.lock_rounded,
  'family': Icons.family_restroom_rounded,
  'music': Icons.music_note_rounded,
  'video': Icons.videocam_rounded,
  'tv': Icons.tv_rounded,
  'gamepad': Icons.sports_esports_rounded,
  'headphones': Icons.headphones_rounded,
  'download': Icons.download_rounded,
  'globe': Icons.public_rounded,
  'coffee': Icons.coffee_rounded,
};

/// 6 color presets matching the v2 brand palette.  Keys are the hex
/// string we persist to `groups.color TEXT`; values are the parsed
/// [Color] for rendering.  Same fallback pattern as icons.
const Map<String, Color> kGroupColorChoices = <String, Color>{
  '#A855F7': Color(0xFFA855F7), // violet — default for "Public"
  '#06B6D4': Color(0xFF06B6D4), // cyan
  '#F59E0B': Color(0xFFF59E0B), // amber
  '#10B981': Color(0xFF10B981), // emerald
  '#EC4899': Color(0xFFEC4899), // pink
  '#64748B': Color(0xFF64748B), // slate
};

/// Resolve a stored `groups.icon` value to an [IconData], falling back
/// to `Icons.group_rounded` for null / unknown keys.  Public uses
/// `'public'` (set by migration 025) which isn't in the picker — render
/// it as the globe.
IconData groupIconData(String? key) {
  if (key == null) return Icons.group_rounded;
  if (key == 'public') return Icons.public_rounded;
  return kGroupIconChoices[key] ?? Icons.group_rounded;
}

/// Resolve a stored `groups.color` value to a [Color], falling back to
/// the V2 violet for null / unknown keys.
Color groupColor(String? key) {
  if (key == null) return AppColors.violet;
  return kGroupColorChoices[key] ?? AppColors.violet;
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

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
          Row(
            children: [
              const Icon(
                Icons.emoji_emotions_outlined,
                size: 14,
                color: AppColors.textMutedV2,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Icon',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: () => onChanged(null),
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
          const SizedBox(height: AppSpacing.s10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: kGroupIconChoices.entries.map((entry) {
              final isSel = value == entry.key;
              return GestureDetector(
                onTap: () => onChanged(entry.key),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0x2EA855F7)
                          : const Color(0x08FFFFFF),
                      border: Border.all(
                        color: isSel
                            ? const Color(0x80A855F7)
                            : const Color(0x0FFFFFFF),
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Icon(
                      entry.value,
                      size: 16,
                      color: isSel
                          ? AppColors.violetSoft
                          : AppColors.textMutedV2,
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

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

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
          Row(
            children: [
              const Icon(
                Icons.palette_outlined,
                size: 14,
                color: AppColors.textMutedV2,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Color',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (value != null)
                GestureDetector(
                  onTap: () => onChanged(null),
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
          const SizedBox(height: AppSpacing.s10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kGroupColorChoices.entries.map((entry) {
              final isSel = value == entry.key;
              return GestureDetector(
                onTap: () => onChanged(entry.key),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: entry.value,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSel
                            ? AppColors.textBright
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: isSel
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
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

// ── Concurrent-streams field ──────────────────────────────────────────────
//
// Per-group cap on simultaneous active streams (M7 Tier-2 of
// `13_groups_v2_content_spaces.md`).  Schema column already exists on
// `groups` (migration 025).  Empty input = no cap; a positive integer
// caps the count.  Server enforcement lives at stream-start.

class _ConcurrentStreamsField extends StatefulWidget {
  const _ConcurrentStreamsField({
    required this.value,
    required this.onChanged,
  });

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_ConcurrentStreamsField> createState() =>
      _ConcurrentStreamsFieldState();
}

class _ConcurrentStreamsFieldState extends State<_ConcurrentStreamsField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.value == null ? '' : widget.value.toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _ConcurrentStreamsField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the controller in sync with the parent's source of truth so
    // a server-side hydrate after Save reseeds the field correctly.
    final expected =
        widget.value == null ? '' : widget.value.toString();
    if (_ctrl.text != expected) {
      _ctrl.text = expected;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
          Row(
            children: [
              const Icon(
                Icons.stream_rounded,
                size: 14,
                color: AppColors.textMutedV2,
              ),
              const SizedBox(width: AppSpacing.s8),
              Expanded(
                child: Text(
                  'Per-group concurrent stream cap',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBright,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'Stream-start returns 503 when this many members are already '
            'streaming from this group.  Leave empty for no per-group cap '
            '(the global tier limit still applies).',
            style: AppTypography.captionV2.copyWith(
              color: AppColors.textDim,
            ),
          ),
          const SizedBox(height: AppSpacing.s10),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'No cap',
                border: OutlineInputBorder(),
                suffixText: 'streams',
              ),
              onChanged: (v) {
                final t = v.trim();
                if (t.isEmpty) {
                  widget.onChanged(null);
                  return;
                }
                final parsed = int.tryParse(t);
                if (parsed == null || parsed < 1 || parsed > 100) {
                  // Invalid input — don't fire onChanged with a bogus
                  // value.  The TextField stays in its raw state until
                  // the operator types something parseable.
                  return;
                }
                widget.onChanged(parsed);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Danger Zone card — Delete group + Reset all PINs.  Deliberately at
/// the bottom of Overview (operator scrolls past identity + status to
/// reach it) and styled with red borders so accidental clicks are
/// unlikely.  Both actions confirm via [FluxGlassDialog] before firing.
class _DangerZoneCard extends StatelessWidget {
  const _DangerZoneCard({
    required this.group,
    required this.memberCount,
  });

  final Group group;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: const Color(0x0CDC2626), // ~5% red wash
        border: Border.all(color: const Color(0x40DC2626)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 14,
                color: AppColors.red,
              ),
              const SizedBox(width: AppSpacing.s8),
              Text(
                'Danger Zone',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textBright,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s12),
          if (group.requiresPin) ...[
            _DangerRow(
              title: 'Reset all PINs',
              caption: group.pinModel == PinModel.perClient
                  ? 'Drops every member\'s per-client enrollment + active '
                      'grant.  Each member re-enrolls on next access.'
                  : 'Drops every active PIN grant.  Members re-enter the '
                      'shared PIN on next access.',
              actionLabel: 'Reset',
              onPressed: () => _confirmResetPins(context),
            ),
            const SizedBox(height: AppSpacing.s8),
          ],
          _DangerRow(
            title: 'Delete group',
            caption:
                'Removes the group and unassigns all $memberCount '
                '${memberCount == 1 ? "member" : "members"}.  Files on disk '
                'are never affected.',
            actionLabel: 'Delete',
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    // Capture cubit + router BEFORE any await so the analyzer's
    // use-build-context-synchronously lint clears.  Both refs are
    // safe to use after the originating widget unmounts — the cubit
    // is owned by the page-level BlocProvider, and GoRouter handles
    // post-dispose navigation gracefully.
    final cubit = context.read<GroupsCubit>();
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => FluxGlassDialog(
        title: Text('Delete "${group.name}"?'),
        content: Text(
          'This removes the group and its $memberCount member '
          '${memberCount == 1 ? "association" : "associations"}.  '
          'In-flight streams continue; the next stream-start applies '
          'the new (no-group) visibility.\n\n'
          'Files on disk are never deleted by Fluxora.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await cubit.deleteGroup(group.id);
    router.go(Routes.groups);
  }

  Future<void> _confirmResetPins(BuildContext context) async {
    // Capture cubit + messenger BEFORE any await — analyzer can't
    // follow `mounted` checks across async gaps reliably, and both
    // refs are safe to use post-dispose (cubit is page-scoped; the
    // messenger walks up to the nearest live one).
    final cubit = context.read<GroupsCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final isPerClient = group.pinModel == PinModel.perClient;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => FluxGlassDialog(
        title: const Text('Reset all PINs?'),
        content: Text(
          isPerClient
              ? 'Every member\'s per-client PIN enrollment will be '
                  'cleared along with their active grants.  Each '
                  'member sets up a new PIN on next access.'
              : 'Every active PIN grant for this group will be '
                  'cleared.  Members re-enter the shared PIN on next '
                  'access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.violet),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!isPerClient) {
      // Shared mode — single bulk endpoint drops every active grant
      // for the group; members re-enter the shared PIN on next access.
      try {
        final repo = GetIt.I<GroupsRepository>();
        final dropped = await repo.resetAllGrants(group.id);
        // Refresh the cubit so the Members tab badges drop their
        // "Unlocked" chips immediately.
        await cubit.loadMembers(group.id, includePinState: true);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              dropped == 0
                  ? 'No active grants to reset.'
                  : 'Reset $dropped grant${dropped == 1 ? "" : "s"}.',
            ),
            backgroundColor: AppColors.emerald,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Reset failed: $e')),
        );
      }
      return;
    }
    // Per-client: walk every member + clear their PIN.  No bulk
    // endpoint — sequential is fine for household-scale member counts.
    final members = (cubit.state is GroupsLoaded)
        ? (cubit.state as GroupsLoaded).members
        : <Map<String, dynamic>>[];
    for (final m in members) {
      final cid =
          (m['client_id'] as String?) ?? (m['id'] as String?) ?? '';
      if (cid.isNotEmpty) {
        try {
          await cubit.clearMemberPin(group.id, cid);
        } catch (_) {
          // Best-effort sweep — continue past individual failures so
          // one bad row doesn't abort the rest.
        }
      }
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('PINs reset'),
        backgroundColor: AppColors.emerald,
      ),
    );
  }
}

class _DangerRow extends StatelessWidget {
  const _DangerRow({
    required this.title,
    required this.caption,
    required this.actionLabel,
    required this.onPressed,
  });

  final String title;
  final String caption;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textBright,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: AppTypography.captionV2.copyWith(
                  color: AppColors.textMutedV2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.s12),
        FluxButton(
          variant: FluxButtonVariant.danger,
          size: FluxButtonSize.sm,
          onPressed: onPressed,
          child: Text(actionLabel),
        ),
      ],
    );
  }
}

// ── Activity tab ───────────────────────────────────────────────────────────
//
// Group-scoped slice of the existing activity feed.  Pulls events with
// `target_kind=group` + `target_id=<group_id>` so member adds, PIN
// unlocks, etc emitted by `group_service` write paths land here.

class _ActivityTab extends StatefulWidget {
  const _ActivityTab({required this.groupId});

  final String groupId;

  @override
  State<_ActivityTab> createState() => _ActivityTabState();
}

class _ActivityTabState extends State<_ActivityTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _events = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.groupId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final api = GetIt.I<ApiClient>();
      // Existing /api/v1/activity supports `target_kind` + `target_id`
      // filters; the response is a list of activity records.  We avoid
      // a typed entity here because the page renders the rows directly
      // — the desktop ActivityCubit doesn't expose a per-target query.
      final raw = await api.get<List<dynamic>>(
        '${Endpoints.activity}?target_kind=group&target_id=${widget.groupId}'
            '&limit=50',
        fromJson: (json) => json as List<dynamic>,
      );
      if (!mounted) return;
      setState(() {
        _events =
            raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load activity: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent activity',
                style: AppTypography.body.copyWith(
                  color: AppColors.textBright,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FluxButton(
              variant: FluxButtonVariant.ghost,
              size: FluxButtonSize.sm,
              icon: Icons.refresh_rounded,
              onPressed: _loading
                  ? null
                  : () {
                      setState(() {
                        _loading = true;
                        _error = null;
                      });
                      _load();
                    },
              child: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.s12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.violet,
                ),
              ),
            ),
          )
        else if (_error != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: const Color(0x06FFFFFF),
              border: Border.all(color: const Color(0x14FFFFFF)),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              _error!,
              style: AppTypography.captionV2.copyWith(
                color: AppColors.red,
              ),
            ),
          )
        else if (_events.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.s24),
            decoration: BoxDecoration(
              color: const Color(0x06FFFFFF),
              border: Border.all(color: const Color(0x14FFFFFF)),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Center(
              child: Text(
                'No recent activity for this group.',
                style: AppTypography.captionV2.copyWith(
                  color: AppColors.textMutedV2,
                ),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0x06FFFFFF),
              border: Border.all(color: const Color(0x14FFFFFF)),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Column(
              children: [
                for (var i = 0; i < _events.length; i++) ...[
                  if (i > 0)
                    const Divider(
                      height: 1,
                      color: Color(0x10FFFFFF),
                    ),
                  _ActivityRow(event: _events[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.event});

  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final type = event['type'] as String? ?? 'unknown';
    final summary = event['summary'] as String? ?? type;
    final createdAt = event['created_at'] as String? ?? '';
    final icon = switch (type) {
      'group.member.add' => Icons.person_add_alt_rounded,
      'group.member.remove' => Icons.person_remove_alt_1_rounded,
      'group.pin.unlock' => Icons.lock_open_rounded,
      'group.pin.cleared' => Icons.lock_reset_rounded,
      _ => Icons.timeline_outlined,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s12,
        vertical: AppSpacing.s10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.violetTint),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textBody,
                  ),
                ),
                if (createdAt.isNotEmpty)
                  Text(
                    createdAt,
                    style: AppTypography.captionV2.copyWith(
                      color: AppColors.textDim,
                      fontFamily: 'JetBrainsMono',
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

// ── View As tab ────────────────────────────────────────────────────────────
//
// Operator-only debug.  Picks a target client (must be a member of the
// current group, plus optionally any other paired client) and renders
// the `VisibleLibraries` snapshot the server would return for them
// right now.  Provenance + locked-state buckets surface so the operator
// understands *why* a library is or isn't visible.

class _ViewAsTab extends StatefulWidget {
  const _ViewAsTab({required this.groupMembers});

  final List<Map<String, dynamic>> groupMembers;

  @override
  State<_ViewAsTab> createState() => _ViewAsTabState();
}

class _ViewAsTabState extends State<_ViewAsTab> {
  String? _selectedClientId;
  String? _selectedClientName;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'View library access as',
          style: AppTypography.body.copyWith(
            color: AppColors.textBright,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.s4),
        Text(
          'Pick a member to render their visible-libraries snapshot.  '
          'Honest about current state — PIN-locked groups appear locked, '
          'time-locked groups appear time-locked.',
          style: AppTypography.captionV2.copyWith(
            color: AppColors.textMutedV2,
          ),
        ),
        const SizedBox(height: AppSpacing.s12),
        if (widget.groupMembers.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.s16),
            decoration: BoxDecoration(
              color: const Color(0x06FFFFFF),
              border: Border.all(color: const Color(0x14FFFFFF)),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(
              'No members yet — add one from the Members tab to enable '
              'View as.',
              style: AppTypography.captionV2.copyWith(
                color: AppColors.textMutedV2,
              ),
            ),
          )
        else ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: widget.groupMembers.map((m) {
              final id = (m['client_id'] as String?) ??
                  (m['id'] as String?) ??
                  '';
              final name = (m['name'] as String?) ?? id;
              final isSel = _selectedClientId == id;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedClientId = id;
                    _selectedClientName = name;
                  });
                  _runLookup(id);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSel
                          ? const Color(0x2EA855F7)
                          : const Color(0x08FFFFFF),
                      border: Border.all(
                        color: isSel
                            ? const Color(0x80A855F7)
                            : const Color(0x0FFFFFFF),
                      ),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Text(
                      name,
                      style: AppTypography.bodySmall.copyWith(
                        color: isSel
                            ? AppColors.violetSoft
                            : AppColors.textBody,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.s16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.s24),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.violet,
                  ),
                ),
              ),
            )
          else if (_error != null)
            Text(
              _error!,
              style: AppTypography.captionV2.copyWith(color: AppColors.red),
            )
          else if (_result != null)
            _ViewAsResultCard(
              clientName: _selectedClientName ?? '',
              result: _result!,
            )
          else
            Text(
              'Pick a member above to preview what they see.',
              style: AppTypography.captionV2.copyWith(
                color: AppColors.textDim,
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _runLookup(String clientId) async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final repo = GetIt.I<GroupsRepository>();
      final r = await repo.visibleLibrariesAs(clientId);
      if (!mounted) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Lookup failed: $e';
        _loading = false;
      });
    }
  }
}

class _ViewAsResultCard extends StatelessWidget {
  const _ViewAsResultCard({
    required this.clientName,
    required this.result,
  });

  final String clientName;
  final Map<String, dynamic> result;

  @override
  Widget build(BuildContext context) {
    final libIds =
        (result['library_ids'] as List<dynamic>? ?? const []).cast<String>();
    final provenance = (result['groups_contributing'] as Map<String, dynamic>?)
            ?.map(
              (k, v) =>
                  MapEntry(k, (v as List<dynamic>).cast<String>()),
            ) ??
        const <String, List<String>>{};
    final pinLocked = (result['pin_locked_groups'] as List<dynamic>? ??
            const [])
        .cast<String>();
    final enrollmentReq =
        (result['enrollment_required_groups'] as List<dynamic>? ?? const [])
            .cast<String>();
    final timeLocked = (result['time_locked_groups'] as List<dynamic>? ??
            const [])
        .cast<String>();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.s16),
      decoration: BoxDecoration(
        color: const Color(0x06FFFFFF),
        border: Border.all(color: const Color(0x14FFFFFF)),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Visible libraries (${libIds.length})',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textBright,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          if (libIds.isEmpty)
            Text(
              '$clientName sees nothing right now.',
              style: AppTypography.captionV2.copyWith(
                color: AppColors.textDim,
              ),
            )
          else
            ...libIds.map((id) {
              // Find which group(s) granted this library so we can
              // render "← granted by Public".
              final grantingGroups = provenance.entries
                  .where((e) => e.value.contains(id))
                  .map((e) => e.key)
                  .toList();
              final grantCaption = grantingGroups.isEmpty
                  ? null
                  : '← granted by ${grantingGroups.join(", ")}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.folder_open_rounded,
                      size: 14,
                      color: AppColors.textMutedV2,
                    ),
                    const SizedBox(width: AppSpacing.s8),
                    Expanded(
                      child: Text(
                        id,
                        style: AppTypography.captionV2.copyWith(
                          color: AppColors.textBody,
                          fontFamily: 'JetBrainsMono',
                        ),
                      ),
                    ),
                    if (grantCaption != null)
                      Text(
                        grantCaption,
                        style: AppTypography.captionV2.copyWith(
                          color: AppColors.textDim,
                        ),
                      ),
                  ],
                ),
              );
            }),
          if (pinLocked.isNotEmpty || enrollmentReq.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Locked groups',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textBright,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            ...pinLocked.map((g) => _LockedRow(
                  groupId: g,
                  caption: 'requires PIN unlock',
                )),
            ...enrollmentReq.map((g) => _LockedRow(
                  groupId: g,
                  caption: 'per-client mode — not enrolled',
                )),
          ],
          if (timeLocked.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s12),
            Text(
              'Time-locked groups',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textBright,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.s4),
            ...timeLocked.map((g) => _LockedRow(
                  groupId: g,
                  caption: 'outside the time window right now',
                )),
          ],
        ],
      ),
    );
  }
}

class _LockedRow extends StatelessWidget {
  const _LockedRow({required this.groupId, required this.caption});

  final String groupId;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: AppColors.amber,
          ),
          const SizedBox(width: AppSpacing.s8),
          Expanded(
            child: Text(
              groupId,
              style: AppTypography.captionV2.copyWith(
                color: AppColors.textBody,
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ),
          Text(
            caption,
            style: AppTypography.captionV2.copyWith(
              color: AppColors.textDim,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared loading + state shells ──────────────────────────────────────────

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.violet,
        ),
      ),
    );
  }
}

class _FailureShell extends StatelessWidget {
  const _FailureShell({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: AppTypography.body
                .copyWith(color: AppColors.textMutedV2),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.s16),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            icon: Icons.refresh_rounded,
            onPressed: () => context.read<GroupsCubit>().load(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _MissingShell extends StatelessWidget {
  const _MissingShell({required this.requestedId});

  final String requestedId;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 36,
            color: AppColors.textMutedV2,
          ),
          const SizedBox(height: AppSpacing.s14),
          Text(
            'Group no longer exists',
            style: AppTypography.body.copyWith(
              color: AppColors.textBright,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          Text(
            'id $requestedId — it may have been deleted from another window.',
            style: AppTypography.captionV2.copyWith(
              color: AppColors.textMutedV2,
            ),
          ),
          const SizedBox(height: AppSpacing.s16),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            icon: Icons.arrow_back_rounded,
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go(Routes.groups);
              }
            },
            child: const Text('Back to groups'),
          ),
        ],
      ),
    );
  }
}
