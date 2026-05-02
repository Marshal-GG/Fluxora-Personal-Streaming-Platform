/// Groups screen — placeholder until M5 builds the full surface.
///
/// Server endpoints already exist (§7.1 Groups: `GET /api/v1/groups`,
/// `GET /api/v1/groups/{id}/members`, etc.). This shell shows an empty
/// state so the route resolves cleanly during M2.
library;

import 'package:flutter/material.dart';
import 'package:fluxora_core/fluxora_core.dart';
import 'package:fluxora_desktop/shared/widgets/flux_button.dart';
import 'package:fluxora_desktop/shared/widgets/page_header.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Groups',
            subtitle: 'Organise clients and apply shared streaming restrictions',
            actions: FluxButton(
              icon: Icons.add,
              onPressed: () {},
              child: const Text('Create group'),
            ),
          ),
          const Expanded(
            child: Center(
              child: EmptyState(
                illustration: EmptyStateIllustration.clients,
                title: 'No groups yet',
                message:
                    'Create your first group to bundle clients with shared library access, time windows, and bandwidth caps.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
