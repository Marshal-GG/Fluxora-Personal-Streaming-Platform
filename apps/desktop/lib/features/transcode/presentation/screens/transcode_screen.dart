import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'package:fluxora_core/constants/app_colors.dart';
import 'package:fluxora_core/constants/app_spacing.dart';

import 'package:fluxora_desktop/features/transcode/domain/repositories/transcode_repository.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_cubit.dart';
import 'package:fluxora_desktop/features/transcode/presentation/cubit/transcode_state.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/candidates_tab.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/history_tab.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/queue_tab.dart';
import 'package:fluxora_desktop/features/transcode/presentation/widgets/storage_strip.dart';
import 'package:fluxora_desktop/shared/widgets/flux_tab_bar.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';

/// Three-tab Transcode page — `Candidates`, `Queue`, `History`.  All
/// three tabs read from the same [TranscodeCubit] so a job that lands
/// in the Queue tab is visible to the History tab on the very next poll
/// without an extra fetch.
class TranscodeScreen extends StatelessWidget {
  const TranscodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TranscodeCubit>(
      create: (_) => TranscodeCubit(
        repository: GetIt.I<TranscodeRepository>(),
      )..start(),
      child: const _TranscodeView(),
    );
  }
}

class _TranscodeView extends StatefulWidget {
  const _TranscodeView();

  @override
  State<_TranscodeView> createState() => _TranscodeViewState();
}

class _TranscodeViewState extends State<_TranscodeView> {
  static const String _tabCandidates = 'candidates';
  static const String _tabQueue = 'queue';
  static const String _tabHistory = 'history';

  String _activeTab = _tabCandidates;

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              title: 'Transcode',
              subtitle:
                  'Pre-convert AV1 / VP9 sources to H.264 sidecars so playback stream-copies',
            ),
            // Plan 19 §M3 — persistent storage info strip above the
            // tab bar. Reads from the cubit's storage slice (5 s poll).
            const StorageStrip(),
            BlocBuilder<TranscodeCubit, TranscodeState>(
              buildWhen: (a, b) => _countsChanged(a, b),
              builder: (context, state) {
                final tabs = _buildTabs(state);
                return FluxTabBar(
                  tabs: tabs,
                  activeId: _activeTab,
                  onChange: (id) => setState(() => _activeTab = id),
                );
              },
            ),
            const SizedBox(height: AppSpacing.s18),
            // Each tab renders inline rather than via TabBarView — the
            // single shared cubit drives all three, so swapping widgets
            // is enough.  No PageStorage / IndexedStack: the tabs are
            // cheap to rebuild and cubit state is preserved.
            switch (_activeTab) {
              _tabCandidates => const CandidatesTab(),
              _tabQueue => const QueueTab(),
              _tabHistory => const HistoryTab(),
              _ => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }

  List<FluxTab> _buildTabs(TranscodeState state) {
    int candidatesCount = 0;
    int queueCount = 0;
    int historyCount = 0;
    if (state is TranscodeLoaded) {
      candidatesCount = state.candidates.length;
      queueCount = state.activeJobs.length;
      historyCount = state.terminalJobs.length;
    }
    return [
      FluxTab(
        id: _tabCandidates,
        label: 'Candidates'
            '${candidatesCount == 0 ? '' : ' ($candidatesCount)'}',
        icon: Icons.fast_forward_rounded,
      ),
      FluxTab(
        id: _tabQueue,
        label: 'Queue${queueCount == 0 ? '' : ' ($queueCount)'}',
        icon: Icons.hourglass_top_rounded,
      ),
      FluxTab(
        id: _tabHistory,
        label: 'History${historyCount == 0 ? '' : ' ($historyCount)'}',
        icon: Icons.history_rounded,
      ),
    ];
  }

  /// Rebuild the tab bar only when one of the three counts changes —
  /// avoids spinning the FluxTabBar 30× a minute on /jobs polls that
  /// only mutate progress percentages.
  bool _countsChanged(TranscodeState a, TranscodeState b) {
    if (a is! TranscodeLoaded || b is! TranscodeLoaded) return true;
    return a.candidates.length != b.candidates.length ||
        a.activeJobs.length != b.activeJobs.length ||
        a.terminalJobs.length != b.terminalJobs.length;
  }
}
