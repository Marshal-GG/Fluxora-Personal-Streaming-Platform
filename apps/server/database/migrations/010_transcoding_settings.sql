-- Add transcoding configuration to user_settings
ALTER TABLE user_settings ADD COLUMN transcoding_encoder TEXT NOT NULL DEFAULT 'libx264';
ALTER TABLE user_settings ADD COLUMN transcoding_preset TEXT NOT NULL DEFAULT 'veryfast';
ALTER TABLE user_settings ADD COLUMN transcoding_crf INTEGER NOT NULL DEFAULT 23;
