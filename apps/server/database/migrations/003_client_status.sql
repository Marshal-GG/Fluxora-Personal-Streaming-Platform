-- Add status column to clients for pairing state machine
-- Possible values: 'pending', 'approved', 'rejected'
ALTER TABLE clients ADD COLUMN status TEXT NOT NULL DEFAULT 'pending';
