-- Migration 008: Polar webhook order tracking
-- Records processed Polar paid orders to guarantee idempotent
-- key issuance (Polar retries on non-2xx; duplicate processing must be safe).

CREATE TABLE IF NOT EXISTS polar_orders (
    order_id       TEXT PRIMARY KEY,          -- Polar order ID
    tier           TEXT NOT NULL,             -- plus | pro | ultimate
    license_key    TEXT NOT NULL,             -- the generated FLUXORA-... key
    processed_at   TEXT NOT NULL              -- ISO-8601 UTC datetime
);
