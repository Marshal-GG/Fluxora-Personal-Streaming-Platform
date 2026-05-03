/// Episodes screen for shows.
///
/// Phase A backfill trimmed the mock-driven season selector + episode
/// rows from this screen — show aggregation needs `tmdb_show_id`-grouped
/// SQL plus a new `GET /shows/{id}/episodes` endpoint, which both ship in
/// Phase D.  The route (`/episodes/:id`) still exists so existing deep
/// links don't 404; until Phase D wires real data, the screen renders a
/// "Coming soon" placeholder.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:go_router/go_router.dart';

import 'package:fluxora_mobile/core/router/app_router.dart';

class EpisodesScreen extends StatelessWidget {
  const EpisodesScreen({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: FluxAppBar(
        title: 'Episodes',
        onBack: () =>
            context.canPop() ? context.pop() : context.go(Routes.home),
      ),
      body: const _ComingSoon(),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.tv_outlined,
                size: 48, color: AppColors.textDim),
            const SizedBox(height: 12),
            Text(
              'Episodes — coming soon',
              style: AppTypography.h2.copyWith(color: AppColors.textBright),
            ),
            const SizedBox(height: 6),
            Text(
              'TV-show episode browsing lands once the server back-fills '
              'show / season / episode metadata for your library. Movies '
              'and individual files already play from the title screen.',
              textAlign: TextAlign.center,
              style: AppTypography.captionV2
                  .copyWith(color: AppColors.textMutedV2),
            ),
          ],
        ),
      ),
    );
  }
}
