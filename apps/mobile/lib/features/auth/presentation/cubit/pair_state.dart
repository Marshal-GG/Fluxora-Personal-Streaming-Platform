/// Pairing state machine.
///
/// Two flows feed this machine:
///
/// 1. **Initial pair** (entry: `connect_screen` → tap a discovered server)
///    `PairInitial` → `PairCollectEmail(server)` → `PairRequesting` →
///    `PairPending` → `PairApproved` (or `PairRejected` / `PairError`).
///
/// 2. **Reconnect** (entry: `Routes.reconnect`, e.g. token revoked /
///    invalidated by a re-pair on another device)
///    `PairInitial` → `PairRequesting` → `PairPending` → `PairApproved`.
///    Email collection is skipped — the server already has the row from
///    the original pair, the email column is preserved by the
///    `COALESCE(excluded.email, clients.email)` clause in
///    `auth_service.create_pair_request`.
library;

import 'package:fluxora_mobile/features/connect/domain/entities/discovered_server.dart';

sealed class PairState {
  const PairState();
}

class PairInitial extends PairState {
  const PairInitial();
}

/// Pre-request step shown to first-time pairers — captures the optional
/// email field documented in `docs/04_api/01_api_contracts.md` for
/// `POST /auth/request-pair`. The screen renders a "Skip" affordance
/// alongside "Continue" so the user can opt out.
class PairCollectEmail extends PairState {
  const PairCollectEmail({required this.server});

  final DiscoveredServer server;
}

class PairRequesting extends PairState {
  const PairRequesting();
}

class PairPending extends PairState {
  const PairPending();
}

class PairApproved extends PairState {
  const PairApproved();
}

class PairRejected extends PairState {
  const PairRejected(this.reason);

  final String reason;
}

class PairError extends PairState {
  const PairError(this.message);

  final String message;
}
