import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_radii.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_desktop/core/di/injector.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_select.dart';
import 'package:fluxora_desktop/shared/widgets/flux_slider.dart';
import 'package:fluxora_desktop/shared/widgets/flux_switch.dart';
import 'package:fluxora_desktop/shared/widgets/flux_text_field.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/pill.dart';
import 'package:fluxora_desktop/shared/widgets/status_dot.dart';

// ── Tier metadata ──────────────────────────────────────────────────────────────

const _kEncoders = ['libx264', 'h264_nvenc', 'h264_qsv', 'h264_vaapi'];
const _kPresets = ['ultrafast', 'superfast', 'veryfast', 'faster', 'fast', 'medium', 'slow'];

// ── Entry point ────────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SettingsCubit>()..loadSettings(),
      child: const _SettingsView(),
    );
  }
}

// ── Main stateful view ─────────────────────────────────────────────────────────

class _SettingsView extends StatefulWidget {
  const _SettingsView();

  @override
  State<_SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<_SettingsView> {
  // ── Tab state ─────────────────────────────────────────────────────────────
  String _activeTab = 'general';

  // ── Controller / local form values ───────────────────────────────────────
  // These are initialised once the first SettingsLoaded arrives via _syncFromState.
  late final TextEditingController _urlCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _licenseCtrl;
  late final TextEditingController _relayCtrl;
  late final TextEditingController _customUrlCtrl;
  late final TextEditingController _sessionTimeoutCtrl;
  late final TextEditingController _aiSegmentCtrl;

  // Non-text fields tracked locally
  bool _autoStartOnBoot = false;
  bool _autoRestartOnCrash = false;
  bool _minimizeToTray = false;
  bool _scanOnStartup = true;
  bool _generateThumbnails = true;
  String _defaultLibraryView = 'grid';
  String _language = 'en';
  String _defaultQuality = 'auto';
  bool _transcodingEnabled = true;
  String _transcodingEncoder = 'libx264';
  String _transcodingPreset = 'veryfast';
  double _transcodingCrf = 23;
  bool _enablePairingRequired = true;
  bool _enableLogExport = false;
  String _selectedTier = 'free';
  bool _initialized = false;

  // ── Dirty tracking ────────────────────────────────────────────────────────
  // A simple flag; we compare text controllers to the last-loaded snapshot.
  SettingsLoaded? _loadedSnapshot;

  bool get _isDirty {
    final s = _loadedSnapshot;
    if (s == null) return false;
    return _urlCtrl.text != s.serverUrl ||
        _nameCtrl.text != s.serverName ||
        _selectedTier != s.tier ||
        _transcodingEnabled != true || // always allow save
        _transcodingEncoder != s.transcodingEncoder ||
        _transcodingPreset != s.transcodingPreset ||
        _transcodingCrf.round() != s.transcodingCrf ||
        (_licenseCtrl.text.trim().isEmpty ? null : _licenseCtrl.text.trim()) !=
            s.licenseKey;
  }

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController();
    _nameCtrl = TextEditingController();
    _licenseCtrl = TextEditingController();
    _relayCtrl = TextEditingController();
    _customUrlCtrl = TextEditingController();
    _sessionTimeoutCtrl = TextEditingController(text: '60');
    _aiSegmentCtrl = TextEditingController(text: '6');

    // Rebuild on text changes so the Save button reacts.
    for (final c in [_urlCtrl, _nameCtrl, _licenseCtrl]) {
      c.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _urlCtrl, _nameCtrl, _licenseCtrl, _relayCtrl,
      _customUrlCtrl, _sessionTimeoutCtrl, _aiSegmentCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  void _syncFromState(SettingsLoaded s) {
    if (_urlCtrl.text != s.serverUrl) _urlCtrl.text = s.serverUrl;
    if (_nameCtrl.text != s.serverName) _nameCtrl.text = s.serverName;
    final key = s.licenseKey ?? '';
    if (_licenseCtrl.text != key) _licenseCtrl.text = key;
    if (!_initialized) {
      _selectedTier = s.tier;
      _transcodingEncoder = s.transcodingEncoder;
      _transcodingPreset = s.transcodingPreset;
      _transcodingCrf = s.transcodingCrf.toDouble();
      _initialized = true;
    }
    _loadedSnapshot = s;
  }

  void _save(BuildContext context) {
    context.read<SettingsCubit>().saveSettings(
          serverUrl: _urlCtrl.text,
          serverName: _nameCtrl.text,
          tier: _selectedTier,
          licenseKey: _licenseCtrl.text.trim().isEmpty
              ? null
              : _licenseCtrl.text.trim(),
          transcodingEncoder: _transcodingEncoder,
          transcodingPreset: _transcodingPreset,
          transcodingCrf: _transcodingCrf.round(),
        );
  }


  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state is SettingsLoaded) _syncFromState(state);
        if (state is SettingsSaved) {
          setState(() {}); // clear dirty
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Settings saved.'),
              backgroundColor: AppColors.emerald,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm)),
            ),
          );
        }
        if (state is SettingsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.sm)),
            ),
          );
        }
      },
      builder: (context, state) {
        final loaded = state is SettingsLoaded ? state : null;
        final isLoading = state is SettingsLoading;

        return Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.s28,
            right: AppSpacing.s28,
            bottom: AppSpacing.s28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page header
              PageHeader(
                title: 'Settings',
                subtitle: 'Configure your server preferences and system settings',
                actions: FluxButton(
                  variant: FluxButtonVariant.primary,
                  size: FluxButtonSize.sm,
                  icon: Icons.save_outlined,
                  onPressed: (isLoading || !_isDirty)
                      ? null
                      : () => _save(context),
                  child: const Text('Save Changes'),
                ),
              ),

              // Tab row
              _SettingsTabRow(
                activeId: _activeTab,
                onChange: (id) => setState(() => _activeTab = id),
              ),

              const SizedBox(height: AppSpacing.s18),

              // Tab content
              Expanded(
                child: SingleChildScrollView(
                  child: switch (_activeTab) {
                    'network'   => _NetworkTab(state: loaded, cubit: context.read()),
                    'streaming' => _StreamingTab(
                        enabled: _transcodingEnabled,
                        encoder: _transcodingEncoder,
                        preset: _transcodingPreset,
                        crf: _transcodingCrf,
                        aiSegmentCtrl: _aiSegmentCtrl,
                        onEnabledChanged: (v) => setState(() { _transcodingEnabled = v; }),
                        onEncoderChanged: (v) => setState(() { _transcodingEncoder = v; }),
                        onPresetChanged: (v) => setState(() { _transcodingPreset = v; }),
                        onCrfChanged: (v) => setState(() { _transcodingCrf = v; }),
                        defaultQuality: _defaultQuality,
                        onQualityChanged: (v) => setState(() { _defaultQuality = v; }),
                        maxStreams: loaded?.maxConcurrentStreams ?? 1,
                      ),
                    'security'  => _SecurityTab(
                        licenseCtrl: _licenseCtrl,
                        sessionTimeoutCtrl: _sessionTimeoutCtrl,
                        pairingRequired: _enablePairingRequired,
                        tier: loaded?.tier ?? _selectedTier,
                        onPairingChanged: (v) => setState(() { _enablePairingRequired = v; }),
                      ),
                    'advanced'  => _AdvancedTab(
                        enableLogExport: _enableLogExport,
                        customUrlCtrl: _customUrlCtrl,
                        onLogExportChanged: (v) => setState(() { _enableLogExport = v; }),
                      ),
                    'about'     => _AboutTab(state: loaded),
                    _           => _GeneralTab(
                        nameCtrl: _nameCtrl,
                        language: _language,
                        autoStartOnBoot: _autoStartOnBoot,
                        autoRestartOnCrash: _autoRestartOnCrash,
                        minimizeToTray: _minimizeToTray,
                        scanOnStartup: _scanOnStartup,
                        generateThumbnails: _generateThumbnails,
                        defaultLibraryView: _defaultLibraryView,
                        state: loaded,
                        onLanguageChanged: (v) => setState(() { _language = v; }),
                        onAutoStartChanged: (v) => setState(() { _autoStartOnBoot = v; }),
                        onAutoRestartChanged: (v) => setState(() { _autoRestartOnCrash = v; }),
                        onMinimizeChanged: (v) => setState(() { _minimizeToTray = v; }),
                        onScanChanged: (v) => setState(() { _scanOnStartup = v; }),
                        onThumbnailsChanged: (v) => setState(() { _generateThumbnails = v; }),
                        onLibraryViewChanged: (v) => setState(() { _defaultLibraryView = v; }),
                      ),
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Custom tab row (side-by-side icon + label, active = violet underline) ──────

class _SettingsTabRow extends StatelessWidget {
  const _SettingsTabRow({
    required this.activeId,
    required this.onChange,
  });

  final String activeId;
  final ValueChanged<String> onChange;

  static const _tabs = [
    (id: 'general',   label: 'General',   icon: Icons.settings_outlined),
    (id: 'network',   label: 'Network',   icon: Icons.wifi_outlined),
    (id: 'streaming', label: 'Streaming', icon: Icons.play_circle_outline),
    (id: 'security',  label: 'Security',  icon: Icons.shield_outlined),
    (id: 'advanced',  label: 'Advanced',  icon: Icons.tune_outlined),
    (id: 'about',     label: 'About',     icon: Icons.info_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x0FFFFFFF)),
        ),
      ),
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 0),
      child: Row(
        children: [
          for (final tab in _tabs)
            _SettingsTabItem(
              id: tab.id,
              label: tab.label,
              icon: tab.icon,
              isActive: activeId == tab.id,
              onTap: () => onChange(tab.id),
            ),
        ],
      ),
    );
  }
}

class _SettingsTabItem extends StatefulWidget {
  const _SettingsTabItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String id;
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  State<_SettingsTabItem> createState() => _SettingsTabItemState();
}

class _SettingsTabItemState extends State<_SettingsTabItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.isActive
        ? AppColors.violetTint
        : (_hovered ? AppColors.textBody : AppColors.textMutedV2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 13),
          margin: const EdgeInsets.only(bottom: -1),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.isActive
                    ? AppColors.violet
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 13, color: color),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: widget.isActive
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: color,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Setting block (card with icon header) ─────────────────────────────────────

class _SettingBlock extends StatelessWidget {
  const _SettingBlock({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0x0AFFFFFF)),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, size: 15, color: AppColors.violet),
                const SizedBox(width: 10),
                Text(title, style: AppTypography.h2),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Setting field row (label + sub + control) ─────────────────────────────────

class _SField extends StatelessWidget {
  const _SField({
    required this.label,
    required this.control,
    this.sub,
  });

  final String label;
  final String? sub;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textBody,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textDim,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          control,
        ],
      ),
    );
  }
}

// ── GENERAL TAB ───────────────────────────────────────────────────────────────

class _GeneralTab extends StatelessWidget {
  const _GeneralTab({
    required this.nameCtrl,
    required this.language,
    required this.autoStartOnBoot,
    required this.autoRestartOnCrash,
    required this.minimizeToTray,
    required this.scanOnStartup,
    required this.generateThumbnails,
    required this.defaultLibraryView,
    required this.state,
    required this.onLanguageChanged,
    required this.onAutoStartChanged,
    required this.onAutoRestartChanged,
    required this.onMinimizeChanged,
    required this.onScanChanged,
    required this.onThumbnailsChanged,
    required this.onLibraryViewChanged,
  });

  final TextEditingController nameCtrl;
  final String language;
  final bool autoStartOnBoot;
  final bool autoRestartOnCrash;
  final bool minimizeToTray;
  final bool scanOnStartup;
  final bool generateThumbnails;
  final String defaultLibraryView;
  final SettingsLoaded? state;
  final ValueChanged<String> onLanguageChanged;
  final ValueChanged<bool> onAutoStartChanged;
  final ValueChanged<bool> onAutoRestartChanged;
  final ValueChanged<bool> onMinimizeChanged;
  final ValueChanged<bool> onScanChanged;
  final ValueChanged<bool> onThumbnailsChanged;
  final ValueChanged<String> onLibraryViewChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              // Server Information card
              _SettingBlock(
                icon: Icons.settings_outlined,
                title: 'General Settings',
                children: [
                  _SField(
                    label: 'Server Name',
                    sub: 'This name will be visible to other devices',
                    control: FluxTextField(controller: nameCtrl),
                  ),
                  _SField(
                    label: 'Language',
                    sub: 'Choose your preferred language',
                    control: FluxSelect<String>(
                      value: language,
                      items: const [
                        FluxSelectItem(value: 'en', label: 'English'),
                      ],
                      onChanged: onLanguageChanged,
                    ),
                  ),
                  _SField(
                    label: 'Auto Start on Boot',
                    sub: 'Start the server automatically when system boots',
                    control: FluxSwitch(
                        value: autoStartOnBoot,
                        onChanged: onAutoStartChanged),
                  ),
                  _SField(
                    label: 'Auto Restart on Crash',
                    sub: 'Automatically restart the server if it crashes',
                    control: FluxSwitch(
                        value: autoRestartOnCrash,
                        onChanged: onAutoRestartChanged),
                  ),
                  _SField(
                    label: 'Minimize to System Tray',
                    sub: 'Keep the app running in the system tray when closed',
                    control: FluxSwitch(
                        value: minimizeToTray,
                        onChanged: onMinimizeChanged),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Media Library card
              _SettingBlock(
                icon: Icons.folder_outlined,
                title: 'Media Library Settings',
                children: [
                  _SField(
                    label: 'Default Library View',
                    sub: 'Choose how to display your media',
                    control: FluxSelect<String>(
                      value: defaultLibraryView,
                      items: const [
                        FluxSelectItem(value: 'grid', label: 'Grid View'),
                        FluxSelectItem(value: 'list', label: 'List View'),
                      ],
                      onChanged: onLibraryViewChanged,
                    ),
                  ),
                  _SField(
                    label: 'Scan Library on Startup',
                    sub: 'Automatically scan for new media files',
                    control: FluxSwitch(
                        value: scanOnStartup,
                        onChanged: onScanChanged),
                  ),
                  _SField(
                    label: 'Generate Thumbnails',
                    sub: 'Generate video thumbnails for better browsing',
                    control: FluxSwitch(
                        value: generateThumbnails,
                        onChanged: onThumbnailsChanged),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(width: 14),

        // Right sidebar: System Info card
        SizedBox(
          width: 320,
          child: _SystemInfoCard(state: state),
        ),
      ],
    );
  }
}

class _SystemInfoCard extends StatelessWidget {
  const _SystemInfoCard({required this.state});
  final SettingsLoaded? state;

  @override
  Widget build(BuildContext context) {
    return FluxCard(
      padding: AppSpacing.s18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dns_outlined,
                  size: 16, color: AppColors.violet),
              SizedBox(width: 10),
              Text('System Information', style: AppTypography.h2),
            ],
          ),
          const SizedBox(height: 14),
          const _InfoRow(
            label: 'Server Status',
            valueWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusDot(status: DotStatus.online, size: 6),
                SizedBox(width: 6),
                Text('Running',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: AppColors.emerald)),
              ],
            ),
          ),
          _InfoRow(
              label: 'Server URL',
              value: state?.serverUrl ?? '—'),
          if (state?.remoteUrl != null)
            _InfoRow(label: 'Public URL', value: state!.remoteUrl!),
          _InfoRow(label: 'Subscription', value: state?.tier ?? '—'),
          const _InfoRow(label: 'App Version', value: '0.1.0'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.valueWidget});
  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x0AFFFFFF)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textDim)),
          valueWidget ??
              Text(
                value ?? '—',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textBody,
                ),
              ),
        ],
      ),
    );
  }
}

// ── NETWORK TAB ───────────────────────────────────────────────────────────────

class _NetworkTab extends StatefulWidget {
  const _NetworkTab({required this.state, required this.cubit});
  final SettingsLoaded? state;
  final SettingsCubit cubit;

  @override
  State<_NetworkTab> createState() => _NetworkTabState();
}

class _NetworkTabState extends State<_NetworkTab> {
  bool _enableMdns = true;
  bool _enableWebrtc = true;
  String _preferredMode = 'auto';
  final _relayCtrl = TextEditingController();

  @override
  void dispose() {
    _relayCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final remoteUrl = state?.remoteUrl;
    final configured = remoteUrl != null && remoteUrl.isNotEmpty;

    return Column(
      children: [
        // Connectivity card
        _SettingBlock(
          icon: Icons.wifi_outlined,
          title: 'Connectivity',
          children: [
            _SField(
              label: 'Preferred Mode',
              sub: 'How the server picks a transport for streaming',
              control: FluxSelect<String>(
                value: _preferredMode,
                items: const [
                  FluxSelectItem(value: 'auto', label: 'Auto'),
                  FluxSelectItem(value: 'lan', label: 'LAN only'),
                  FluxSelectItem(value: 'webrtc', label: 'WebRTC only'),
                ],
                onChanged: (v) => setState(() => _preferredMode = v),
              ),
            ),
            _SField(
              label: 'Enable mDNS Discovery',
              sub: 'Broadcast server on local network for auto-discovery',
              control: FluxSwitch(
                  value: _enableMdns,
                  onChanged: (v) => setState(() => _enableMdns = v)),
            ),
            _SField(
              label: 'Enable WebRTC',
              sub: 'Allow WebRTC-based streaming for off-LAN clients',
              control: FluxSwitch(
                  value: _enableWebrtc,
                  onChanged: (v) => setState(() => _enableWebrtc = v)),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Remote Access card (preserves existing behaviour)
        _SettingBlock(
          icon: Icons.public_outlined,
          title: 'Remote Access',
          children: [
            _SField(
              label: 'Public URL',
              sub: configured
                  ? 'Off-LAN clients reach this server through Cloudflare Tunnel.'
                  : 'Set FLUXORA_PUBLIC_URL on the server to enable off-LAN access.',
              control: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x08FFFFFF),
                  borderRadius: BorderRadius.circular(7),
                  border: const Border.fromBorderSide(
                      BorderSide(color: Color(0x14FFFFFF))),
                ),
                child: Text(
                  configured ? remoteUrl : 'Not configured',
                  style: TextStyle(
                    fontFamily: configured ? 'JetBrains Mono' : 'Inter',
                    fontSize: 12,
                    color: configured
                        ? AppColors.textBody
                        : AppColors.textDim,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (configured && state != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    _ReachabilityBadge(
                        status: state.remoteAccessStatus),
                    const SizedBox(width: 12),
                    FluxButton(
                      variant: FluxButtonVariant.ghost,
                      size: FluxButtonSize.sm,
                      icon: Icons.refresh,
                      onPressed:
                          state.remoteAccessStatus ==
                                  RemoteAccessStatus.checking
                              ? null
                              : () => widget.cubit.checkRemoteAccess(),
                      child: const Text('Check now'),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 14),

        // Relay server card
        _SettingBlock(
          icon: Icons.router_outlined,
          title: 'Relay Server',
          children: [
            _SField(
              label: 'Relay Server URL',
              sub: 'Optional TURN/STUN relay server for WebRTC',
              control: FluxTextField(
                  controller: _relayCtrl, hint: 'turn:relay.example.com:3478'),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Reachability badge (preserved from legacy screen) ─────────────────────────

class _ReachabilityBadge extends StatelessWidget {
  const _ReachabilityBadge({required this.status});
  final RemoteAccessStatus? status;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      RemoteAccessStatus.reachable =>
        ('Tunnel reachable', AppColors.emerald, Icons.check_circle_outline),
      RemoteAccessStatus.unreachable =>
        ('Tunnel unreachable', AppColors.red, Icons.error_outline),
      RemoteAccessStatus.checking =>
        ('Checking…', AppColors.textMutedV2, Icons.hourglass_empty_outlined),
      null =>
        ('Not checked yet', AppColors.textMutedV2, Icons.help_outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}

// ── STREAMING TAB ─────────────────────────────────────────────────────────────

class _StreamingTab extends StatelessWidget {
  const _StreamingTab({
    required this.enabled,
    required this.encoder,
    required this.preset,
    required this.crf,
    required this.aiSegmentCtrl,
    required this.onEnabledChanged,
    required this.onEncoderChanged,
    required this.onPresetChanged,
    required this.onCrfChanged,
    required this.defaultQuality,
    required this.onQualityChanged,
    required this.maxStreams,
  });

  final bool enabled;
  final String encoder;
  final String preset;
  final double crf;
  final TextEditingController aiSegmentCtrl;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<String> onEncoderChanged;
  final ValueChanged<String> onPresetChanged;
  final ValueChanged<double> onCrfChanged;
  final String defaultQuality;
  final ValueChanged<String> onQualityChanged;
  final int maxStreams;

  @override
  Widget build(BuildContext context) {
    final maxStreamsLabel = maxStreams >= 9999
        ? 'Unlimited'
        : '$maxStreams concurrent stream${maxStreams == 1 ? '' : 's'} (tier limit)';

    return Column(
      children: [
        // Quality card
        _SettingBlock(
          icon: Icons.high_quality_outlined,
          title: 'Quality',
          children: [
            _SField(
              label: 'Default Quality',
              sub: 'Fallback quality when the client does not specify',
              control: FluxSelect<String>(
                value: defaultQuality,
                items: const [
                  FluxSelectItem(value: 'auto', label: 'Auto'),
                  FluxSelectItem(value: '4k', label: '4K (2160p)'),
                  FluxSelectItem(value: '1080p', label: '1080p'),
                  FluxSelectItem(value: '720p', label: '720p'),
                  FluxSelectItem(value: '480p', label: '480p'),
                ],
                onChanged: onQualityChanged,
              ),
            ),
            _SField(
              label: 'Max Concurrent Streams',
              sub: maxStreamsLabel,
              control: FluxTextField(
                controller: TextEditingController(text: '$maxStreams'),
                keyboardType: TextInputType.number,
                enabled: false,
                width: 80,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Transcoding card
        _SettingBlock(
          icon: Icons.transform_outlined,
          title: 'Transcoding',
          children: [
            _SField(
              label: 'Enable Transcoding',
              sub: 'Re-encode media for compatible devices',
              control:
                  FluxSwitch(value: enabled, onChanged: onEnabledChanged),
            ),
            _SField(
              label: 'Encoder',
              sub: 'Hardware encoder requires compatible GPU',
              control: FluxSelect<String>(
                value: encoder,
                items: _kEncoders
                    .map((e) => FluxSelectItem(value: e, label: e))
                    .toList(),
                onChanged: onEncoderChanged,
                enabled: enabled,
              ),
            ),
            _SField(
              label: 'Preset',
              sub: 'Slower preset = better compression',
              control: FluxSelect<String>(
                value: preset,
                items: _kPresets
                    .map((p) => FluxSelectItem(value: p, label: p))
                    .toList(),
                onChanged: onPresetChanged,
                enabled: enabled,
              ),
            ),
            _SField(
              label: 'CRF (quality): ${crf.round()}',
              sub: '0 = lossless · 51 = lowest quality',
              control: SizedBox(
                width: 200,
                child: FluxSlider(
                  value: crf,
                  min: 0,
                  max: 51,
                  divisions: 51,
                  label: '${crf.round()}',
                  onChanged: enabled ? onCrfChanged : null,
                ),
              ),
            ),
            _SField(
              label: 'AI Segment Duration (seconds)',
              sub: 'HLS segment length for AI-optimised streaming',
              control: FluxTextField(
                controller: aiSegmentCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                width: 80,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── SECURITY TAB ──────────────────────────────────────────────────────────────

class _SecurityTab extends StatelessWidget {
  const _SecurityTab({
    required this.licenseCtrl,
    required this.sessionTimeoutCtrl,
    required this.pairingRequired,
    required this.tier,
    required this.onPairingChanged,
  });

  final TextEditingController licenseCtrl;
  final TextEditingController sessionTimeoutCtrl;
  final bool pairingRequired;
  final String tier;
  final ValueChanged<bool> onPairingChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Pairing card
        _SettingBlock(
          icon: Icons.devices_outlined,
          title: 'Pairing',
          children: [
            _SField(
              label: 'Require Pairing',
              sub: 'New clients must be approved before they can connect',
              control: FluxSwitch(
                  value: pairingRequired,
                  onChanged: onPairingChanged),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Sessions card
        _SettingBlock(
          icon: Icons.timer_outlined,
          title: 'Sessions',
          children: [
            _SField(
              label: 'Session Timeout (minutes)',
              sub: 'Idle sessions are expired after this period (1–1440)',
              control: FluxTextField(
                controller: sessionTimeoutCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                width: 80,
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // License card
        _SettingBlock(
          icon: Icons.vpn_key_outlined,
          title: 'License',
          children: [
            _SField(
              label: 'License Key',
              sub: 'Enter your Polar license key to activate a paid plan',
              control: FluxTextField(
                controller: licenseCtrl,
                obscureText: true,
                hint: 'FLUXORA-XXXX-XXXX-XXXX-XXXX',
              ),
            ),
            _SField(
              label: 'Subscription Tier',
              sub: 'Current active plan',
              control: Pill(
                tier.toUpperCase(),
                color: switch (tier) {
                  'plus' => PillColor.info,
                  'pro' => PillColor.purple,
                  'ultimate' => PillColor.warning,
                  _ => PillColor.neutral,
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: FluxButton(
                variant: FluxButtonVariant.ghost,
                size: FluxButtonSize.sm,
                icon: Icons.receipt_long_outlined,
                onPressed: () => context.go('/licenses'),
                child: const Text('View Issued Licenses'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── ADVANCED TAB ──────────────────────────────────────────────────────────────

class _AdvancedTab extends StatelessWidget {
  const _AdvancedTab({
    required this.enableLogExport,
    required this.customUrlCtrl,
    required this.onLogExportChanged,
  });

  final bool enableLogExport;
  final TextEditingController customUrlCtrl;
  final ValueChanged<bool> onLogExportChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logging card
        _SettingBlock(
          icon: Icons.article_outlined,
          title: 'Logging',
          children: [
            _SField(
              label: 'Enable Log Export',
              sub: 'Allow exporting server logs from the Logs screen',
              control: FluxSwitch(
                  value: enableLogExport,
                  onChanged: onLogExportChanged),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Server URL override card
        _SettingBlock(
          icon: Icons.link_outlined,
          title: 'Server URL Override',
          children: [
            _SField(
              label: 'Custom Server URL',
              sub: 'Only override if you know what you\'re doing',
              control: FluxTextField(
                controller: customUrlCtrl,
                hint: 'https://custom.example.com',
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Reset card
        const _ResetCard(),
      ],
    );
  }
}

// ── Reset card (const-constructible, no controllers) ─────────────────────────

class _ResetCard extends StatelessWidget {
  const _ResetCard();

  @override
  Widget build(BuildContext context) {
    return const _SettingBlock(
      icon: Icons.restore_outlined,
      title: 'Reset',
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Disabled — no backend reset endpoint yet.
              _DisabledResetButton(),
              SizedBox(height: 6),
              Text(
                'No backend reset endpoint available yet.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DisabledResetButton extends StatelessWidget {
  const _DisabledResetButton();

  @override
  Widget build(BuildContext context) {
    return const FluxButton(
      variant: FluxButtonVariant.danger,
      size: FluxButtonSize.sm,
      icon: Icons.restore_outlined,
      onPressed: null,
      child: Text('Reset to Defaults'),
    );
  }
}

// ── ABOUT TAB ─────────────────────────────────────────────────────────────────

class _AboutTab extends StatelessWidget {
  const _AboutTab({required this.state});
  final SettingsLoaded? state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Server info card
        _SettingBlock(
          icon: Icons.dns_outlined,
          title: 'Server',
          children: [
            const _SField(
              label: 'App Version',
              control: Text('0.1.0',
                  style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      color: AppColors.textBody)),
            ),
            if (state != null)
              _SField(
                label: 'Server URL',
                control: Text(
                  state!.serverUrl,
                  style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      color: AppColors.textBody),
                ),
              ),
          ],
        ),

        const SizedBox(height: 14),

        // Links card
        const _LinksCard(),

        const SizedBox(height: 14),

        // Credits card
        const _CreditsCard(),
      ],
    );
  }
}

class _LinksCard extends StatelessWidget {
  const _LinksCard();

  static const _links = [
    (Icons.code_outlined, 'GitHub Repository',
        'https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform'),
    (Icons.menu_book_outlined, 'Documentation',
        'https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/wiki'),
    (Icons.bug_report_outlined, 'Report an Issue',
        'https://github.com/Marshal-GG/Fluxora-Personal-Streaming-Platform/issues'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SettingBlock(
      icon: Icons.link_outlined,
      title: 'Links',
      children: [
        for (final link in _links)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Icon(link.$1, size: 14, color: AppColors.textMutedV2),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    link.$2,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textBody,
                    ),
                  ),
                ),
                const Icon(Icons.open_in_new, size: 13, color: AppColors.violet),
              ],
            ),
          ),
      ],
    );
  }
}

class _CreditsCard extends StatelessWidget {
  const _CreditsCard();

  @override
  Widget build(BuildContext context) {
    return const _SettingBlock(
      icon: Icons.favorite_border_outlined,
      title: 'Credits',
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Text(
            'Built with Flutter, FastAPI, FFmpeg, and ❤',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textBody,
            ),
          ),
        ),
      ],
    );
  }
}
