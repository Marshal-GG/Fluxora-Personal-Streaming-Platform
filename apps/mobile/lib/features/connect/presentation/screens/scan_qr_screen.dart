/// QR-code pairing scanner.
///
/// Phase B QA round (2026-05-04) — fallback path when mDNS discovery
/// can't reach the server (router blocks multicast, AP isolation, mobile
/// on guest VLAN, etc.).  Mobile camera reads the canonical
/// `fluxora://pair?host=&port=&name=` payload rendered by the desktop
/// control panel; payload parsed via [PairingUri.tryParse].
///
/// On success, configures [ApiClient] with the scanned LAN URL and
/// navigates to `/pairing` with the parsed [DiscoveredServer].  The
/// scanner stops as soon as a valid code is detected so the user
/// doesn't get a re-scan loop on the next frame.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';
import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';
import 'package:fluxora_mobile/features/connect/domain/pairing_uri.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  late final MobileScannerController _controller;
  bool _consumed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_consumed) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null || raw.isEmpty) continue;
      final server = PairingUri.tryParse(raw);
      if (server != null) {
        _consumed = true;
        await HapticFeedback.lightImpact();
        await _controller.stop();
        if (!mounted) return;
        GetIt.I<ApiClient>().configure(localBaseUrl: server.url);
        context.go(Routes.pairing, extra: server);
        return;
      }
      // Show one error at a time — preserves the rest of the scanner UI.
      setState(() {
        _errorMessage =
            'That QR code isn\'t a Fluxora pairing code. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.connect),
          tooltip: 'Back',
        ),
        title: const Text(
          'Scan QR code',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torchOn = state.torchState == TorchState.on;
              return IconButton(
                icon: Icon(
                  torchOn ? Icons.flash_on : Icons.flash_off,
                  color: Colors.white,
                ),
                tooltip: torchOn ? 'Turn flashlight off' : 'Turn flashlight on',
                onPressed: () => _controller.toggleTorch(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) =>
                _PermissionError(error: error.errorCode),
          ),
          const _ReticleOverlay(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xCC0F0C24),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Text(
                        'Open the desktop control panel and pick '
                        '"Pair device" — the QR shown there encodes your '
                        'server\'s LAN address.',
                        textAlign: TextAlign.center,
                        style: AppTypography.captionV2.copyWith(
                          color: Colors.white,
                          height: 1.4,
                        ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xCC2C0F1A),
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0x66EF4444)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              size: 18,
                              color: Color(0xFFF87171),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: AppTypography.captionV2
                                    .copyWith(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReticleOverlay extends StatelessWidget {
  const _ReticleOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Reticle is the smaller of 70% width or 60% height, capped 320px.
          final side = (constraints.maxWidth * 0.7)
              .clamp(160.0, constraints.maxHeight * 0.6)
              .clamp(160.0, 320.0);
          return Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outside-the-reticle dim layer (rule-of-thirds gap kept
                // unblocked so the user can frame the QR easily).
                ColoredBox(
                  color: const Color(0x88000000),
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                  ),
                ),
                Container(
                  width: side,
                  height: side,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    border:
                        Border.all(color: AppColors.violet, width: 2.5),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x80A855F7),
                        blurRadius: 30,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                // Center hole — punch the dim layer with a transparent box
                // matching the reticle.  Achieved via BackdropFilter trick.
                _ReticleHole(side: side),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ReticleHole extends StatelessWidget {
  const _ReticleHole({required this.side});

  final double side;

  @override
  Widget build(BuildContext context) {
    // ClipPath cuts out the reticle from the dim overlay.  Simpler than
    // a full custom-paint approach and works on every Flutter target.
    return ClipPath(
      clipper: _ReticleClipper(side: side),
      child: const ColoredBox(color: Colors.transparent),
    );
  }
}

class _ReticleClipper extends CustomClipper<Path> {
  _ReticleClipper({required this.side});

  final double side;

  @override
  Path getClip(Size size) {
    final centerRect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    return Path()
      ..addRect(Offset.zero & size)
      ..addRRect(RRect.fromRectAndRadius(
        centerRect,
        const Radius.circular(20),
      ))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  bool shouldReclip(_ReticleClipper old) => old.side != side;
}

class _PermissionError extends StatelessWidget {
  const _PermissionError({required this.error});

  final MobileScannerErrorCode error;

  String get _message {
    switch (error) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Camera permission was denied. Allow camera access in '
            'system settings to scan a QR code.';
      case MobileScannerErrorCode.unsupported:
        return 'This device doesn\'t support QR scanning. Use "Enter '
            'server address manually" on the previous screen.';
      default:
        return 'Couldn\'t open the camera. Restart the app and try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.camera_alt_outlined,
            color: Colors.white70,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            _message,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 18),
          FluxButton(
            variant: FluxButtonVariant.secondary,
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Go back'),
          ),
        ],
      ),
    );
  }
}
