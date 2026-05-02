import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';
import 'package:fluxora_core/constants/app_typography.dart';
import 'package:fluxora_core/entities/stream_session.dart';
import 'package:fluxora_core/entities/transcoding_status.dart';
import 'package:fluxora_desktop/core/router/app_router.dart';
import 'package:fluxora_desktop/features/activity/domain/repositories/activity_repository.dart';
import 'package:fluxora_desktop/features/activity/presentation/cubit/activity_cubit.dart';
import 'package:fluxora_desktop/features/transcoding/domain/repositories/transcoding_repository.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/transcoding_cubit.dart';
import 'package:fluxora_desktop/features/transcoding/presentation/cubit/transcoding_state.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/flux_card.dart';
import 'package:fluxora_desktop/shared/widgets/flux_progress.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';
import 'package:fluxora_desktop/shared/widgets/pill.dart';
import 'package:fluxora_desktop/shared/widgets/stat_tile.dart';

// ── Entry point ────────────────────────────────────────────────────────────────

class TranscodingScreen extends StatelessWidget {
  const TranscodingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<TranscodingCubit>(
          create: (_) => TranscodingCubit(
            repository: GetIt.I<TranscodingRepository>(),
          )..start(),
        ),
        BlocProvider<ActivityCubit>(
          create: (_) =>
              ActivityCubit(GetIt.I<ActivityRepository>())..loadSessions(),
        ),
      ],
      child: const _TranscodingView(),
    );
  }
}

// ── Main view ──────────────────────────────────────────────────────────────────

class _TranscodingView extends StatelessWidget {
  const _TranscodingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgRoot,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: AppSpacing.s28,
          right: AppSpacing.s28,
          bottom: AppSpacing.s28,
        ),
        child: BlocBuilder<TranscodingCubit, TranscodingState>(
          builder: (context, txState) {
            final loaded =
                txState is TranscodingLoaded ? txState.status : null;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────────────────
                PageHeader(
                  title: 'Transcoding',
                  subtitle:
                      'Real-time encoder load and per-session details',
                  actions: FluxButton(
                    variant: FluxButtonVariant.secondary,
                    icon: Icons.settings_outlined,
                    onPressed: () =>
                        context.go(Routes.encoderSettings),
                    child: const Text('Encoder Settings'),
                  ),
                ),

                // ── Stat tiles ───────────────────────────────────────────
                _StatTilesRow(status: loaded),
                const SizedBox(height: AppSpacing.s18),

                // ── Active sessions card ─────────────────────────────────
                _ActiveSessionsCard(txStatus: loaded),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Stat tiles ─────────────────────────────────────────────────────────────────

class _StatTilesRow extends StatelessWidget {
  const _StatTilesRow({required this.status});

  final TranscodingStatus? status;

  @override
  Widget build(BuildContext context) {
    final sessionCount = status?.activeSessions.length ?? 0;
    final encoderName = status?.activeEncoder ?? '—';

    // GPU util from the active encoder's load entry
    String gpuLoad = '—';
    if (status != null) {
      final activeLoad = status!.encoderLoads.where(
        (l) => l.encoder == status!.activeEncoder,
      );
      if (activeLoad.isNotEmpty &&
          activeLoad.first.gpuUtilizationPercent != null) {
        gpuLoad =
            '${activeLoad.first.gpuUtilizationPercent!.toStringAsFixed(0)}%';
      } else if (activeLoad.isNotEmpty &&
          activeLoad.first.cpuUtilizationPercent != null) {
        gpuLoad =
            '${activeLoad.first.cpuUtilizationPercent!.toStringAsFixed(0)}%';
      }
    }

    return Row(
      children: [
        Expanded(
          child: StatTile(
            icon: Icons.memory_outlined,
            label: 'Active Transcodes',
            value: '$sessionCount',
            color: AppColors.violet,
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: StatTile(
            icon: Icons.bolt_outlined,
            label: 'Hardware Encoder',
            value: _shortEncoderName(encoderName),
            color: AppColors.emerald,
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        Expanded(
          child: StatTile(
            icon: Icons.monitor_heart_outlined,
            label: 'Encoder Load',
            value: gpuLoad,
            color: AppColors.pink,
          ),
        ),
        const SizedBox(width: AppSpacing.s14),
        const Expanded(
          child: StatTile(
            icon: Icons.layers_outlined,
            label: 'Queue Depth',
            value: '0',
            color: AppColors.blue,
          ),
        ),
      ],
    );
  }

  String _shortEncoderName(String raw) {
    // Return a short display label from encoder identifier.
    return switch (raw.toLowerCase()) {
      'h264_nvenc' || 'hevc_nvenc' => 'NVENC',
      'h264_qsv' || 'hevc_qsv' => 'QSV',
      'h264_vaapi' => 'VAAPI',
      'h264_amf' => 'AMF',
      'libx264' => 'x264',
      'libx265' => 'x265',
      _ => raw,
    };
  }
}

// ── Active sessions card ───────────────────────────────────────────────────────

class _ActiveSessionsCard extends StatelessWidget {
  const _ActiveSessionsCard({required this.txStatus});

  final TranscodingStatus? txStatus;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ActivityCubit, ActivityState>(
      builder: (context, actState) {
        final sessions = actState.maybeWhen(
          loaded: (s) => s,
          orElse: () => <StreamSession>[],
        );

        return FluxCard(
          padding: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s18,
                  vertical: AppSpacing.s14,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Active Sessions',
                        style: AppTypography.h2),
                    FluxButton(
                      variant: FluxButtonVariant.danger,
                      size: FluxButtonSize.sm,
                      icon: Icons.stop_rounded,
                      onPressed: sessions.isEmpty
                          ? null
                          : () => _stopAll(context, sessions),
                      child: const Text('Stop All'),
                    ),
                  ],
                ),
              ),

              // Rows
              if (sessions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.s28,
                  ),
                  child: Center(
                    child: Text(
                      'No active transcoding sessions.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textDim,
                      ),
                    ),
                  ),
                )
              else
                ...sessions.asMap().entries.map(
                      (entry) => _SessionRow(
                        session: entry.value,
                        isFirst: entry.key == 0,
                        txStatus: txStatus,
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _stopAll(
      BuildContext context, List<StreamSession> sessions) async {
    final cubit = context.read<ActivityCubit>();
    for (final s in sessions) {
      await cubit.stopSession(s.id);
    }
  }
}

// ── Session row ────────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.session,
    required this.isFirst,
    required this.txStatus,
  });

  final StreamSession session;
  final bool isFirst;
  final TranscodingStatus? txStatus;

  @override
  Widget build(BuildContext context) {
    // Try to find matching ActiveTranscodeSession for codec / fps / speed info.
    final atx = txStatus?.activeSessions
        .where((a) => a.id == session.id || a.clientId == session.clientId)
        .firstOrNull;

    final inputCodec = atx?.inputCodec ?? '—';
    final outputCodec = atx?.outputCodec ?? '—';
    final fps = atx?.fps;
    final speed = atx?.speedX;
    final progress = atx?.progress ?? 0.0;

    return Container(
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : const Border(
                top: BorderSide(color: Color(0x08FFFFFF)),
              ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s20,
        vertical: AppSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      atx?.mediaTitle ?? session.fileId,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textBright,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          atx?.clientName ?? session.clientId,
                          style: AppTypography.monoCaption.copyWith(
                            color: AppColors.textDim,
                          ),
                        ),
                        const Text(' · ',
                            style: TextStyle(
                                color: AppColors.textDim, fontSize: 11)),
                        Text(inputCodec,
                            style: AppTypography.monoCaption.copyWith(
                              color: AppColors.textMutedV2,
                            )),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_rounded,
                            size: 11, color: AppColors.textFaint),
                        const SizedBox(width: 4),
                        Text(outputCodec,
                            style: AppTypography.monoCaption.copyWith(
                              color: AppColors.violetTint,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              Row(
                children: [
                  if (fps != null || speed != null)
                    Pill(
                      [
                        if (fps != null)
                          '${fps.toStringAsFixed(0)} fps',
                        if (speed != null)
                          '${speed.toStringAsFixed(1)}×',
                      ].join(' · '),
                      color: PillColor.success,
                    ),
                  const SizedBox(width: AppSpacing.s8),
                  FluxButton(
                    variant: FluxButtonVariant.danger,
                    size: FluxButtonSize.sm,
                    icon: Icons.stop_rounded,
                    onPressed: () =>
                        context.read<ActivityCubit>().stopSession(session.id),
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s10),
          Row(
            children: [
              Expanded(
                child: FluxProgress(
                  value: progress.clamp(0.0, 1.0),
                  color: AppColors.violet,
                ),
              ),
              const SizedBox(width: AppSpacing.s12),
              SizedBox(
                width: 36,
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: AppTypography.monoCaption.copyWith(
                    color: AppColors.textMutedV2,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
