/// PDF document viewer backed by [pdfx].
///
/// Downloads the file via `GET /api/v1/files/{id}/content` to a temp path
/// before opening it with [PdfDocument.openFile] — guarantees compatibility
/// with pdfx 2.x which does not expose a network-loading API.  The same
/// temp file is reused for the "Open in..." share action so no second
/// download is required.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class DocViewerScreen extends StatefulWidget {
  const DocViewerScreen({required this.file, super.key});

  final MediaFile file;

  @override
  State<DocViewerScreen> createState() => _DocViewerScreenState();
}

class _DocViewerScreenState extends State<DocViewerScreen> {
  PdfControllerPinch? _controller;
  String? _tempPath;
  String? _error;
  bool _openingExternal = false;
  static final _log = Logger();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _controller?.dispose();
      _controller = null;
    });
    try {
      final path = await _downloadToTemp();
      if (!mounted) return;
      if (path == null) {
        setState(() => _error = 'Could not download this document.');
        return;
      }
      _tempPath = path;
      final controller = PdfControllerPinch(
        document: PdfDocument.openFile(path),
      );
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e, st) {
      _log.e('PDF load failed for ${widget.file.id}', error: e, stackTrace: st);
      if (mounted) setState(() => _error = 'Could not load this document.');
    }
  }

  Future<String?> _downloadToTemp() async {
    final storage = GetIt.I<SecureStorage>();
    final serverUrl = await storage.getServerUrl();
    final token = await storage.getAuthToken();
    if (serverUrl == null) return null;
    final url = '$serverUrl/api/v1/files/${widget.file.id}/content';

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      if (token != null) request.headers.set('Authorization', 'Bearer $token');
      final response = await request.close();
      if (response.statusCode != 200) return null;
      final dir = await getTemporaryDirectory();
      final dest = File('${dir.path}/${widget.file.name}');
      await response.pipe(dest.openWrite());
      return dest.path;
    } finally {
      client.close();
    }
  }

  Future<void> _openInExternal() async {
    setState(() => _openingExternal = true);
    try {
      final path = _tempPath ?? await _downloadToTemp();
      if (path == null) throw Exception('Download failed');
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          subject: widget.file.title ?? widget.file.name,
        ),
      );
    } catch (e, st) {
      _log.e('Open-in failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open in external app.')),
        );
      }
    } finally {
      if (mounted) setState(() => _openingExternal = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgRoot,
      appBar: AppBar(
        backgroundColor: AppColors.bgRaised,
        iconTheme: const IconThemeData(color: AppColors.textBright),
        title: Text(
          widget.file.title ?? widget.file.name,
          style: AppTypography.h2.copyWith(color: AppColors.textBright),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_openingExternal)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: _openInExternal,
              tooltip: 'Open in...',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final err = _error;
    if (err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.textDim),
              const SizedBox(height: 12),
              Text(
                err,
                style:
                    AppTypography.body.copyWith(color: AppColors.textMutedV2),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    final ctrl = _controller;
    if (ctrl == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return PdfViewPinch(controller: ctrl);
  }
}
