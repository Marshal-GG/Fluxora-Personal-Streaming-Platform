/// Pair-device dialog — renders the QR-pairing payload that the mobile
/// `ScanQrScreen` reads.
///
/// Phase B QA round (2026-05-04): the mobile mDNS discovery fails on
/// some networks (router AP isolation, mobile on guest VLAN, etc.).
/// This dialog gives the operator a visible LAN address + a scannable
/// QR fallback so pairing always works.
///
/// **Payload format** (mirrored in
/// `apps/mobile/lib/features/connect/domain/pairing_uri.dart`):
///   `fluxora://pair?host=<ip>&port=<int>&name=<server-name>`
///
/// **Sources of truth on the desktop side:**
/// - `host` — `SystemStatsCubit.state.latest.lanIp` (`/info/stats` → `lan_ip`).
/// - `port` — extracted from `ApiClient.localBaseUrl` (the desktop is
///   co-located with the server, so its base URL's port equals the
///   server's listening port; no separate config read needed).
/// - `name` — `ServerInfo.serverName`, fetched lazily on dialog open.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:fluxora_desktop/features/system_stats/presentation/cubit/system_stats_cubit.dart';
import 'package:fluxora_desktop/shared/widgets/flux_glass_dialog.dart';

/// Show the pair-device dialog over the active route.  Wires
/// [SystemStatsCubit] from the calling [BuildContext] via
/// `BlocProvider.value` so the QR re-renders on `lan_ip` updates.
Future<void> showPairDeviceDialog(BuildContext context) {
  final statsCubit = context.read<SystemStatsCubit>();
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0xCC0F0C24),
    builder: (dialogCtx) => BlocProvider<SystemStatsCubit>.value(
      value: statsCubit,
      child: const PairDeviceDialog(),
    ),
  );
}

class PairDeviceDialog extends StatefulWidget {
  const PairDeviceDialog({super.key});

  @override
  State<PairDeviceDialog> createState() => _PairDeviceDialogState();
}

class _PairDeviceDialogState extends State<PairDeviceDialog> {
  Future<ServerInfo>? _info;

  @override
  void initState() {
    super.initState();
    // Fetch server name once; cached by the FutureBuilder for the
    // lifetime of the dialog.  No retry button — failure falls back to
    // "Fluxora Server" so the dialog never hard-fails just because
    // /info momentarily 503'd.
    _info = _fetchInfo();
  }

  Future<ServerInfo> _fetchInfo() async {
    final api = GetIt.I<ApiClient>();
    return api.get<ServerInfo>(
      Endpoints.info,
      fromJson: (data) => ServerInfo.fromJson(data as Map<String, dynamic>),
    );
  }

  /// Server's listening port — read off the desktop's own base URL.
  /// The control panel is co-located with the server, so the base URL
  /// it talks to is the same one the mobile needs to reach.
  int get _serverPort {
    final api = GetIt.I<ApiClient>();
    final url = api.localBaseUrl ?? api.remoteBaseUrl;
    if (url == null) return 8000;
    final uri = Uri.tryParse(url);
    if (uri == null) return 8000;
    if (uri.hasPort) return uri.port;
    return uri.scheme == 'https' ? 443 : 80;
  }

  @override
  Widget build(BuildContext context) {
    final lanIp = context.select<SystemStatsCubit, String?>(
      (c) => c.state.latest?.lanIp,
    );
    return FluxGlassDialog(
      maxWidth: 460,
      title: const Text('Pair a new device'),
      content: lanIp == null
          ? const _Loading()
          : FutureBuilder<ServerInfo>(
              future: _info,
              builder: (context, snapshot) {
                final serverName =
                    snapshot.data?.serverName ?? 'Fluxora Server';
                return _Body(
                  hostIp: lanIp,
                  port: _serverPort,
                  serverName: serverName,
                );
              },
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 220,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: AppColors.violet,
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.hostIp,
    required this.port,
    required this.serverName,
  });

  final String hostIp;
  final int port;
  final String serverName;

  String get _payload => Uri(
        scheme: 'fluxora',
        host: 'pair',
        queryParameters: {
          'host': hostIp,
          'port': '$port',
          'name': serverName,
        },
      ).toString();

  String get _manualLine => '$hostIp:$port';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Open the Fluxora mobile app, tap "Scan QR code" on the '
          'connect screen, and point the camera at this code.',
          style: AppTypography.body.copyWith(color: AppColors.textBody),
        ),
        const SizedBox(height: 18),
        Center(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: _payload,
              version: QrVersions.auto,
              size: 220,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF1A0F26),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF1A0F26),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Or enter manually',
          style: AppTypography.eyebrow.copyWith(
            color: AppColors.textMutedV2,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        _CopyableField(value: _manualLine, label: 'Server address'),
        const SizedBox(height: 8),
        Text(
          'Mobile pairing still requires your approval — this code only '
          'tells the phone where your server is.',
          style: AppTypography.captionV2
              .copyWith(color: AppColors.textMutedV2),
        ),
      ],
    );
  }
}

class _CopyableField extends StatefulWidget {
  const _CopyableField({required this.value, required this.label});

  final String value;
  final String label;

  @override
  State<_CopyableField> createState() => _CopyableFieldState();
}

class _CopyableFieldState extends State<_CopyableField> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.value));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              widget.value,
              style: AppTypography.monoBody.copyWith(
                color: AppColors.textBright,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: _copy,
            icon: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 16,
              color:
                  _copied ? AppColors.emerald : AppColors.violetTint,
            ),
            label: Text(
              _copied ? 'Copied' : 'Copy',
              style: AppTypography.captionV2.copyWith(
                color:
                    _copied ? AppColors.emerald : AppColors.violetTint,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}
