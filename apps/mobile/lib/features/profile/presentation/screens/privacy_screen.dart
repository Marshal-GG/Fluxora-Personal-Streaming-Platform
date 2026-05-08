/// Privacy & security screen — M4 of the mobile-settings remediation
/// plan (`docs/10_planning/archive/15_*.md`).
///
/// Exposes:
///  • A "What this device knows about you" panel — read-only Server URL,
///    Remote URL (if the operator enabled remote access), Device ID,
///    App version.  All copyable so the user can share them with their
///    operator for support diagnosis.
///  • A "Maintenance" panel with two destructive-but-recoverable
///    actions: Clear cached images (Flutter's in-memory `imageCache`)
///    and Clear temp downloads (walks `getTemporaryDirectory()` and
///    deletes the pdf / photo "Open in..." artefacts left there by the
///    M11 doc + photo viewers).
///
/// **Not in v1:**
///  • Sign-out-from-all-devices — dropped per plan §6 Q2, Fluxora's
///    auth model is one-client-per-device with no `user → many devices`
///    fan-out to sign out across.
///  • Disk-level cached_network_image clear — would need a direct dep
///    on `flutter_cache_manager`; v1 ships in-memory clear only.  If
///    posters keep stale after a TMDB rotation, defer to v1.1.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:fluxora_mobile/features/profile/presentation/cubit/profile_cubit.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: FluxAppBar(
        title: 'Privacy & security',
        transparent: true,
        onBack: () => context.pop(),
      ),
      body: const SafeArea(top: false, child: _PrivacyBody()),
    );
  }
}

class _PrivacyBody extends StatelessWidget {
  const _PrivacyBody();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        _Eyebrow(label: 'What this device knows about you'),
        SizedBox(height: 6),
        _DeviceInfoPanel(),
        SizedBox(height: 18),
        _Eyebrow(label: 'Maintenance'),
        SizedBox(height: 6),
        _MaintenancePanel(),
        SizedBox(height: 18),
        _Eyebrow(label: 'Sessions'),
        SizedBox(height: 6),
        _SessionsNote(),
      ],
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 0, 0),
      child: Text(
        label,
        style: AppTypography.eyebrow
            .copyWith(color: AppColors.textMutedV2, letterSpacing: 0.4),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, thickness: 1, color: AppColors.borderSubtle);
}

// ── Device info ────────────────────────────────────────────────────────────

class _DeviceInfoPanel extends StatefulWidget {
  const _DeviceInfoPanel();

  @override
  State<_DeviceInfoPanel> createState() => _DeviceInfoPanelState();
}

class _DeviceInfoPanelState extends State<_DeviceInfoPanel> {
  late final Future<_DeviceInfo> _info;

  @override
  void initState() {
    super.initState();
    _info = _load();
  }

  Future<_DeviceInfo> _load() async {
    final storage = GetIt.I<SecureStorage>();
    final pkg = await PackageInfo.fromPlatform();
    final cubitState =
        GetIt.I<ProfileCubit>().state; // singleton; usually loaded
    final deviceId = (cubitState is ProfileLoaded)
        ? cubitState.profile.id
        : await storage.getClientId() ?? '—';
    return _DeviceInfo(
      serverUrl: await storage.getServerUrl() ?? '—',
      remoteUrl: await storage.getRemoteUrl() ?? '—',
      deviceId: deviceId,
      appVersion: 'v${pkg.version} · build ${pkg.buildNumber}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DeviceInfo>(
      future: _info,
      builder: (_, snap) {
        final d = snap.data;
        return _Card(children: [
          _InfoRow(
            icon: Icons.dns_outlined,
            label: 'Server URL',
            value: d?.serverUrl ?? '—',
            copyable: true,
            monospace: true,
          ),
          const _Divider(),
          _InfoRow(
            icon: Icons.cloud_outlined,
            label: 'Remote URL',
            value: d?.remoteUrl ?? '—',
            copyable: d?.remoteUrl != '—',
            monospace: true,
          ),
          const _Divider(),
          _InfoRow(
            icon: Icons.fingerprint_rounded,
            label: 'Device ID',
            value: d?.deviceId ?? '—',
            copyable: true,
            monospace: true,
          ),
          const _Divider(),
          _InfoRow(
            icon: Icons.info_outline_rounded,
            label: 'App version',
            value: d?.appVersion ?? '—',
          ),
        ]);
      },
    );
  }
}

class _DeviceInfo {
  const _DeviceInfo({
    required this.serverUrl,
    required this.remoteUrl,
    required this.deviceId,
    required this.appVersion,
  });

  final String serverUrl;
  final String remoteUrl;
  final String deviceId;
  final String appVersion;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.copyable = false,
    this.monospace = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool copyable;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.violetTint, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.captionV2
                      .copyWith(color: AppColors.textMutedV2),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textBright,
                    fontFamily: monospace ? 'monospace' : null,
                    fontSize: monospace ? 12.5 : null,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (copyable)
            IconButton(
              icon: const Icon(Icons.copy_rounded,
                  size: 16, color: AppColors.textMutedV2),
              splashRadius: 18,
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await Clipboard.setData(ClipboardData(text: value));
                messenger.showSnackBar(
                  SnackBar(content: Text('Copied $label')),
                );
              },
            ),
        ],
      ),
    );
  }
}

// ── Maintenance ────────────────────────────────────────────────────────────

class _MaintenancePanel extends StatefulWidget {
  const _MaintenancePanel();

  @override
  State<_MaintenancePanel> createState() => _MaintenancePanelState();
}

class _MaintenancePanelState extends State<_MaintenancePanel> {
  bool _busyImages = false;
  bool _busyTemp = false;

  static final _log = Logger();

  Future<void> _clearImageCache() async {
    setState(() => _busyImages = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // Flutter's framework-level in-memory image cache.  Disk-level
      // `cached_network_image` clearing would require pulling
      // `flutter_cache_manager` in as a direct dep — see the file
      // header comment for the rationale.
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Cleared in-app image cache.')),
      );
    } catch (e, st) {
      _log.e('Clear image cache failed', error: e, stackTrace: st);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not clear image cache.')),
      );
    } finally {
      if (mounted) setState(() => _busyImages = false);
    }
  }

  Future<void> _clearTempDownloads() async {
    setState(() => _busyTemp = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final dir = await getTemporaryDirectory();
      var deleted = 0;
      var bytes = 0;
      if (dir.existsSync()) {
        await for (final entity in dir.list(followLinks: false)) {
          if (entity is File) {
            try {
              bytes += await entity.length();
              await entity.delete();
              deleted++;
            } catch (e, st) {
              _log.w('Could not delete temp file ${entity.path}',
                  error: e, stackTrace: st);
            }
          }
        }
      }
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            deleted == 0
                ? 'Nothing to clear in temp downloads.'
                : 'Cleared $deleted temp file(s) (${_humanBytes(bytes)}).',
          ),
        ),
      );
    } catch (e, st) {
      _log.e('Clear temp downloads failed', error: e, stackTrace: st);
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not clear temp downloads.')),
      );
    } finally {
      if (mounted) setState(() => _busyTemp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Card(children: [
      _ActionRow(
        icon: Icons.image_outlined,
        label: 'Clear in-app image cache',
        sub: 'Frees memory used by poster + thumbnail decoders.',
        busy: _busyImages,
        onPressed: _clearImageCache,
      ),
      const _Divider(),
      _ActionRow(
        icon: Icons.folder_delete_outlined,
        label: 'Clear temp downloads',
        sub: 'Deletes PDF + image files left over from "Open in..." flows.',
        busy: _busyTemp,
        onPressed: _clearTempDownloads,
      ),
    ]);
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.sub,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String sub;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onPressed,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.violetTint, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textBright),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: AppTypography.captionV2
                        .copyWith(color: AppColors.textMutedV2),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.violet,
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textDim),
          ],
        ),
      ),
    );
  }
}

// ── Sessions note ──────────────────────────────────────────────────────────

class _SessionsNote extends StatelessWidget {
  const _SessionsNote();

  @override
  Widget build(BuildContext context) {
    return _Card(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                color: AppColors.textMutedV2, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Fluxora pairs one device per token. Sign out from this '
                'screen via Profile → Sign out — there are no other '
                'sessions tied to this token.',
                style: AppTypography.captionV2
                    .copyWith(color: AppColors.textMutedV2),
              ),
            ),
          ],
        ),
      ),
    ]);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────

String _humanBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
