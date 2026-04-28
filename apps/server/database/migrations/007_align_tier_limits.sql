-- Align max_concurrent_streams with the actual tier limits.
-- Migration 001 defaulted max_concurrent_streams to 3 on the free tier row,
-- which contradicts the Free tier limit of 1.  This migration corrects
-- existing rows so the value always reflects the current tier.
UPDATE user_settings
SET max_concurrent_streams = CASE subscription_tier
    WHEN 'free'     THEN 1
    WHEN 'plus'     THEN 3
    WHEN 'pro'      THEN 10
    WHEN 'ultimate' THEN 9999
    ELSE 1
END
WHERE id = 1;
