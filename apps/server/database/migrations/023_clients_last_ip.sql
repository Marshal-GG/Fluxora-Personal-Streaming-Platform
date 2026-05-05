-- Adds `last_ip` to `clients` so the desktop Clients screen can show the
-- IP a client most recently authenticated from. Populated by
-- `auth_service.create_pair_request` (initial pair) and
-- `auth_service.update_client_heartbeat` (every authenticated request via
-- the `validate_token` dependency).
--
-- Nullable: existing rows have no recorded IP, and clients that haven't
-- come back since the upgrade will keep showing `—` in the desktop UI
-- until they make their next authenticated request.

ALTER TABLE clients ADD COLUMN last_ip TEXT;
