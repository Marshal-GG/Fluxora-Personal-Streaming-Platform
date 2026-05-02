/// Profile screen — placeholder until M7.
///
/// Server endpoints already exist (§7.2 Profile: `GET /api/v1/profile`,
/// `PATCH /api/v1/profile`, `POST /api/v1/profile/password`). This shell
/// renders an empty-state slot so the sidebar's user-footer tap resolves
/// cleanly during M2.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.s28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Profile',
            subtitle: 'Operator account, security, and active sessions',
          ),
          Expanded(
            child: Center(
              child: EmptyState(
                illustration: EmptyStateIllustration.libraries,
                title: 'Profile screen coming soon',
                message:
                    'Backend endpoints are live. The full Profile surface ships in M7 of the desktop redesign.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
