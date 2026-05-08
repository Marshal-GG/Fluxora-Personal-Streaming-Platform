/// Full-bleed photo viewer backed by [photo_view].
///
/// Streams the image directly from the server via [NetworkImage] with the
/// stored bearer token in the HTTP headers.  The "Open in..." action
/// downloads the file to a temp path first, then triggers the OS share sheet.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/media_file.dart';
import 'package:fluxora_core/storage/secure_storage.dart';
import 'package:logger/logger.dart';

class PhotoViewerScreen extends StatefulWidget {
  const PhotoViewerScreen({required this.file, super.key});

  final MediaFile file;

  @override
  State<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends State<PhotoViewerScreen> {
  String? _imageUrl;
  Map<String, String> _headers = {};
  bool _openingExternal = false;
  static final _log = Logger();

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  Future<void> _resolveUrl() async {
    final storage = GetIt.I<SecureStorage>();
    final serverUrl = await storage.getServerUrl();
    final token = await storage.getAuthToken();
    if (!mounted) return;
    if (serverUrl == null) return;
    setState(() {
      _imageUrl = '$serverUrl/api/v1/files/${widget.file.id}/content';
      _headers = token != null
          ? {'Authorization': 'Bearer $token'}
          : {};
    });
  }

  Future<void> _openInExternal() async {
    setState(() => _openingExternal = true);
    try {
      final storage = GetIt.I<SecureStorage>();
      final serverUrl = await storage.getServerUrl();
      final token = await storage.getAuthToken();
      if (serverUrl == null) return;
      final url = '$serverUrl/api/v1/files/${widget.file.id}/content';

      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(url));
        if (token != null) {
          request.headers.set('Authorization', 'Bearer $token');
        }
        final response = await request.close();
        if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
        final dir = await getTemporaryDirectory();
        final dest = File('${dir.path}/${widget.file.name}');
        await response.pipe(dest.openWrite());
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(dest.path)],
            subject: widget.file.title ?? widget.file.name,
          ),
        );
      } finally {
        client.close();
      }
    } catch (e, st) {
      _log.e('Open-in failed for photo ${widget.file.id}', error: e, stackTrace: st);
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
  Widget build(BuildContext context) {
    final url = _imageUrl;
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black54,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textBright),
        title: Text(
          widget.file.name,
          style: AppTypography.body.copyWith(color: AppColors.textBright),
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
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
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
      body: url == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : PhotoView(
              imageProvider: NetworkImage(url, headers: _headers),
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.broken_image_outlined,
                        size: 64, color: Colors.white54),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load image',
                      style: AppTypography.body
                          .copyWith(color: Colors.white54),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
