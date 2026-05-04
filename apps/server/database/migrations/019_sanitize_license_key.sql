-- Migration 019: Sanitise stale license_key values.
--
-- The Pydantic validator in models/settings.py was tightened from a
-- 4-segment shape (FLUXORA-<TIER>-<EXPIRY>-<HMAC8>) to a 5-segment shape
-- (FLUXORA-<TIER>-<EXPIRY>-<NONCE>-<HMAC8>) at some point during phase 4.
-- Existing rows that still hold an old-format key — or any free-form
-- string the operator typed in before the validator was strict — will
-- 422 the entire PATCH /api/v1/settings call on the next save attempt.
--
-- The settings PATCH layer also has no path to clear a malformed key:
-- update_settings(license_key=None) is a kwarg sentinel meaning "leave
-- unchanged", and an empty string fails the validator. So the operator
-- has no in-app way to recover.  Reset any row whose key isn't in the
-- current 5-segment FLUXORA shape; valid keys (and NULLs) are untouched.

UPDATE user_settings
SET license_key = NULL
WHERE license_key IS NOT NULL
  AND (
    -- Reject anything that doesn't start with the FLUXORA prefix.
    upper(license_key) NOT LIKE 'FLUXORA-%'
    -- Or has anything other than exactly 4 dashes (5 segments).
    -- SQLite has no regex; counting dashes via length-of-stripped-text.
    OR (length(license_key) - length(replace(license_key, '-', ''))) != 4
  );
