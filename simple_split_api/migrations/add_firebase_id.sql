-- Add firebase_id column to users table
ALTER TABLE users ADD COLUMN firebase_id TEXT DEFAULT NULL;

-- Create an index on firebase_id for faster lookups
CREATE INDEX idx_users_firebase_id ON users(firebase_id);

-- Make sure the index is unique when firebase_id is not null
CREATE UNIQUE INDEX idx_users_firebase_id_unique ON users(firebase_id) WHERE firebase_id IS NOT NULL;
