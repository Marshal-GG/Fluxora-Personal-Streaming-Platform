-- Migration 009: Add customer_email to polar_orders
-- Allows the owner to identify which customer owns which license key.

ALTER TABLE polar_orders ADD COLUMN customer_email TEXT;
