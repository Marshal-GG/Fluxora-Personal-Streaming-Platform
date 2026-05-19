import 'package:fluxora_core/entities/client_list_item.dart';

abstract class ClientsRepository {
  Future<List<ClientListItem>> getClients();

  /// `POST /auth/approve/{id}` — moves a `pending` client to `approved`,
  /// generates the bearer token, stamps `paired_at` on first approval.
  Future<void> approveClient(String clientId);

  /// `POST /auth/reject/{id}` — declines a `pending` pair request.
  /// Operator's "no" to a brand-new device that hasn't been trusted yet.
  Future<void> rejectClient(String clientId);

  /// `DELETE /auth/revoke/{id}` — boots an already-approved client off
  /// the server: clears `auth_token`, sets `is_trusted = 0`, marks
  /// `status = 'rejected'`.  The current bearer dies the instant the
  /// request lands.  Different from [rejectClient] semantically — that's
  /// for "I never approved this device", revoke is for "I did, now I'm
  /// taking it back".  The DB row stays so audit history (stream
  /// sessions, activity events) still resolves the client_id.
  Future<void> revokeClient(String clientId);

  /// `DELETE /auth/clients/{id}` — operator-driven hard-delete of a
  /// client row.  Distinct from [revokeClient] which only flips the
  /// row to `status='rejected'` for audit-history preservation; this
  /// actually removes the `clients` row.  Use after a revoke when
  /// the operator wants to clean up the Revoked-filter view.
  Future<void> deleteClient(String clientId);
}
