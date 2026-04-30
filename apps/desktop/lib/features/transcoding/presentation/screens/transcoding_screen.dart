import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:fluxora_desktop/features/settings/presentation/cubit/settings_state.dart';

class TranscodingScreen extends StatefulWidget {
  const TranscodingScreen({super.key});

  @override
  State<TranscodingScreen> createState() => _TranscodingScreenState();
}

class _TranscodingScreenState extends State<TranscodingScreen> {
  String? _selectedEncoder;
  String? _selectedPreset;
  int? _crf;

  final _encoders = [
    {'label': 'Software (x264)', 'value': 'libx264'},
    {'label': 'Software (x265)', 'value': 'libx265'},
    {'label': 'NVIDIA NVENC H.264', 'value': 'h264_nvenc'},
    {'label': 'NVIDIA NVENC HEVC', 'value': 'hevc_nvenc'},
    {'label': 'Intel QuickSync H.264', 'value': 'h264_qsv'},
    {'label': 'Intel QuickSync HEVC', 'value': 'hevc_qsv'},
    {'label': 'AMD AMF H.264', 'value': 'h264_amf'},
    {'label': 'VAAPI H.264', 'value': 'h264_vaapi'},
  ];

  final _presets = [
    'ultrafast',
    'superfast',
    'veryfast',
    'faster',
    'fast',
    'medium',
    'slow',
    'slower',
    'veryslow',
  ];

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state is SettingsLoaded && _selectedEncoder == null) {
          setState(() {
            _selectedEncoder = state.transcodingEncoder;
            _selectedPreset = state.transcodingPreset;
            _crf = state.transcodingCrf;
          });
        }
        if (state is SettingsSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Transcoding settings saved')),
          );
        }
      },
      builder: (context, state) {
        if (state is SettingsLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is! SettingsLoaded) {
          return const Center(child: Text('Failed to load settings'));
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Transcoding'),
            actions: [
              TextButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Save Changes'),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildSection(
                title: 'Video Encoder',
                subtitle:
                    'Choose how the server re-encodes video for streaming. Hardware encoders (NVENC, QSV) are much faster but may have slightly lower quality at the same bitrate.',
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedEncoder,
                  items: _encoders
                      .map((e) => DropdownMenuItem(
                            value: e['value'],
                            child: Text(e['label']!),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedEncoder = v),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildSection(
                title: 'Encoder Preset',
                subtitle:
                    'Faster presets use less CPU/GPU but produce larger files or lower quality. "veryfast" is recommended for real-time streaming.',
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedPreset,
                  items: _presets
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Text(p),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPreset = v),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildSection(
                title: 'Constant Rate Factor (CRF)',
                subtitle:
                    'Lower values mean better quality but higher bitrate. 0-51 range. 23 is default, 18-20 is high quality.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: (_crf ?? 23).toDouble(),
                            min: 0,
                            max: 51,
                            divisions: 51,
                            onChanged: (v) => setState(() => _crf = v.toInt()),
                          ),
                        ),
                        Container(
                          width: 50,
                          alignment: Alignment.center,
                          child: Text(
                            '$_crf',
                            style: AppTypography.bodyMd.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTypography.headingMd),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodySm.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  void _save() {
    final state = context.read<SettingsCubit>().state;
    if (state is! SettingsLoaded) return;

    context.read<SettingsCubit>().saveSettings(
          serverUrl: state.serverUrl,
          serverName: state.serverName,
          tier: state.tier,
          licenseKey: state.licenseKey,
          transcodingEncoder: _selectedEncoder,
          transcodingPreset: _selectedPreset,
          transcodingCrf: _crf,
        );
  }
}
