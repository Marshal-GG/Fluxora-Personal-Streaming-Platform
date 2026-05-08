/// Playback preferences screen — 5 player-related toggles + a quality
/// picker, all backed by [SecureStorage].
///
/// M3 of the mobile-settings remediation plan
/// (`docs/10_planning/archive/15_mobile_settings_remediation_plan.md` §4 M3).
/// Promotes the single inline bg-playback toggle that lived on the
/// Profile screen into a dedicated multi-pref surface.
///
/// The screen owns a [StatefulWidget] (no cubit) — every row is a single
/// [Future] read on first build + a single write on toggle.  The UX
/// matches `_BackgroundPlaybackToggleRow` on the Profile screen: the row
/// is non-interactive while the initial read is in flight (so we don't
/// flip a not-yet-loaded value), then becomes live once the persisted
/// state is known.
///
/// Wi-Fi-only enforcement (refusing to start a stream over cellular)
/// reads the persisted pref via `PlayerCubit` in a follow-up — this
/// screen only stores the user's intent.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

class PlaybackPrefsScreen extends StatefulWidget {
  const PlaybackPrefsScreen({super.key});

  @override
  State<PlaybackPrefsScreen> createState() => _PlaybackPrefsScreenState();
}

class _PlaybackPrefsScreenState extends State<PlaybackPrefsScreen> {
  /// Each value is `null` while the initial read is in flight; becomes
  /// non-null after [_loadAll] completes.  Toggles disable themselves
  /// while their own value is `null` so the user can't flip something
  /// that hasn't loaded yet.
  bool? _bgPlayback;
  bool? _wifiOnly;
  String? _maxQuality;
  bool? _autoplayNext;
  bool? _subtitlesDefaultOn;

  late final SecureStorage _storage = GetIt.I<SecureStorage>();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Five concurrent reads — flutter_secure_storage is async-safe and
    // these are independent keys, so there's no benefit to serialising.
    final results = await Future.wait<Object>([
      _storage.getBackgroundPlaybackEnabled(),
      _storage.getWifiOnlyStreaming(),
      _storage.getMaxStreamingQuality(),
      _storage.getAutoplayNext(),
      _storage.getSubtitlesDefaultOn(),
    ]);
    if (!mounted) return;
    setState(() {
      _bgPlayback = results[0] as bool;
      _wifiOnly = results[1] as bool;
      _maxQuality = results[2] as String;
      _autoplayNext = results[3] as bool;
      _subtitlesDefaultOn = results[4] as bool;
    });
  }

  Future<void> _toggleBgPlayback(bool next) async {
    setState(() => _bgPlayback = next);
    try {
      await _storage.setBackgroundPlaybackEnabled(next);
      // Flipping the pref explicitly counts as having seen the prompt
      // (matches the existing `_BackgroundPlaybackToggleRow` behaviour
      // on the Profile screen — keeps the player from re-asking).
      await _storage.setBackgroundPlaybackPromptShown(true);
    } catch (_) {
      if (mounted) setState(() => _bgPlayback = !next);
    }
  }

  Future<void> _toggleWifiOnly(bool next) async {
    setState(() => _wifiOnly = next);
    try {
      await _storage.setWifiOnlyStreaming(next);
    } catch (_) {
      if (mounted) setState(() => _wifiOnly = !next);
    }
  }

  Future<void> _toggleAutoplayNext(bool next) async {
    setState(() => _autoplayNext = next);
    try {
      await _storage.setAutoplayNext(next);
    } catch (_) {
      if (mounted) setState(() => _autoplayNext = !next);
    }
  }

  Future<void> _toggleSubtitlesDefaultOn(bool next) async {
    setState(() => _subtitlesDefaultOn = next);
    try {
      await _storage.setSubtitlesDefaultOn(next);
    } catch (_) {
      if (mounted) setState(() => _subtitlesDefaultOn = !next);
    }
  }

  Future<void> _pickMaxQuality() async {
    final current = _maxQuality;
    if (current == null) return;
    final picked = await showFluxBottomSheet<String>(
      context: context,
      builder: (sheetCtx) => _QualityPickerSheet(current: current),
    );
    if (picked == null || picked == current || !mounted) return;
    setState(() => _maxQuality = picked);
    try {
      await _storage.setMaxStreamingQuality(picked);
    } catch (_) {
      if (mounted) setState(() => _maxQuality = current);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: FluxAppBar(
        title: 'Playback',
        transparent: true,
        onBack: () => context.pop(),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _PrefsGroup(
              children: [
                _BoolRow(
                  icon: Icons.podcasts_rounded,
                  label: 'Background playback',
                  subOn: 'Audio keeps playing when you minimize the app',
                  subOff: 'Pauses when you minimize the app',
                  value: _bgPlayback,
                  onChanged: _toggleBgPlayback,
                ),
                _BoolRow(
                  icon: Icons.wifi_rounded,
                  label: 'Wi-Fi only streaming',
                  subOn: "Won't start streams over cellular",
                  subOff: 'Streams over any network',
                  value: _wifiOnly,
                  onChanged: _toggleWifiOnly,
                ),
                _QualityRow(
                  value: _maxQuality,
                  onTap: _maxQuality == null ? null : _pickMaxQuality,
                ),
                _BoolRow(
                  icon: Icons.skip_next_rounded,
                  label: 'Autoplay next episode',
                  subOn: 'Auto-advances to the next episode',
                  subOff: 'Stops at end of episode',
                  value: _autoplayNext,
                  onChanged: _toggleAutoplayNext,
                ),
                _BoolRow(
                  icon: Icons.closed_caption_rounded,
                  label: 'Subtitles on by default',
                  subOn: 'Subtitles enabled on new streams',
                  subOff: 'Subtitles off until you turn them on',
                  value: _subtitlesDefaultOn,
                  onChanged: _toggleSubtitlesDefaultOn,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Group container (matches the Profile-screen settings card chrome) ──────

class _PrefsGroup extends StatelessWidget {
  const _PrefsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x08FFFFFF),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: AppColors.borderSubtle,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Boolean toggle row (mirrors _BackgroundPlaybackToggleRow's contract) ───

class _BoolRow extends StatelessWidget {
  const _BoolRow({
    required this.icon,
    required this.label,
    required this.subOn,
    required this.subOff,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subOn;
  final String subOff;

  /// Null while the initial read is in flight — disables the switch +
  /// makes the row's tap a no-op so we don't flip an unloaded value.
  final bool? value;

  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final ready = value != null;
    final v = value ?? false;
    return FluxRow(
      icon: icon,
      label: label,
      sub: v ? subOn : subOff,
      onTap: ready ? () => onChanged(!v) : () {},
      trailing: Switch.adaptive(
        value: v,
        onChanged: ready ? onChanged : null,
        activeThumbColor: AppColors.violet,
      ),
    );
  }
}

// ── Quality enum row (taps through to a FluxBottomSheet picker) ────────────

class _QualityRow extends StatelessWidget {
  const _QualityRow({required this.value, required this.onTap});

  /// Null while the initial read is in flight — same contract as
  /// [_BoolRow.value].
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = value == null ? '—' : _qualityLabel(value!);
    return FluxRow(
      icon: Icons.high_quality_rounded,
      label: 'Max streaming quality',
      sub: 'Caps the player\'s ABR ladder',
      onTap: onTap ?? () {},
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTypography.body.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textBright,
            ),
          ),
          const SizedBox(width: 8),
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

String _qualityLabel(String value) => switch (value) {
      'auto' => 'Auto',
      '1080p' => '1080p',
      '720p' => '720p',
      '480p' => '480p',
      _ => value,
    };

String _qualityCaption(String value) => switch (value) {
      'auto' =>
        'Lets the player pick the best fit for your network',
      '1080p' => 'Cap streams at 1080p',
      '720p' => 'Cap streams at 720p',
      '480p' => 'Cap streams at 480p — saves bandwidth',
      _ => '',
    };

// ── Quality picker sheet (4 selectable rows in a FluxBottomSheet) ──────────

class _QualityPickerSheet extends StatelessWidget {
  const _QualityPickerSheet({required this.current});

  final String current;

  @override
  Widget build(BuildContext context) {
    const options = ['auto', '1080p', '720p', '480p'];
    return FluxBottomSheet(
      title: 'Max streaming quality',
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, color: AppColors.textMutedV2),
        onPressed: () => Navigator.of(context).maybePop(),
        splashRadius: 18,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final option in options)
            _QualityOptionTile(
              value: option,
              selected: option == current,
              onTap: () => Navigator.of(context).pop(option),
            ),
        ],
      ),
    );
  }
}

class _QualityOptionTile extends StatelessWidget {
  const _QualityOptionTile({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.pillBgPurple,
        highlightColor: const Color(0x0AFFFFFF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _qualityLabel(value),
                      style: AppTypography.body.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textBright,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _qualityCaption(value),
                      style: AppTypography.captionV2.copyWith(
                        color: AppColors.textMutedV2,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_rounded,
                  size: 20,
                  color: AppColors.violet,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
