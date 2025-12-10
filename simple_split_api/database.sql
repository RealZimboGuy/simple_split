CREATE TABLE groups (
                        group_id      UUID PRIMARY KEY DEFAULT uuidv7(),
                        name          TEXT NOT NULL,
                        created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE users (
                       user_id      UUID PRIMARY KEY DEFAULT uuidv7(),
                       name          TEXT NOT NULL,
                       created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE events (
                        event_id     UUID PRIMARY KEY NOT NULL,
                        linked_event_id     UUID  NULL,

                        group_id     UUID NOT NULL ,
                        user_id      UUID NOT NULL REFERENCES users(user_id),

                        event_type   TEXT NOT NULL,
                        payload      JSONB NOT NULL,

                        created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_events_group_eventid ON events(group_id, event_id);


-- Add firebase_id column to users table
ALTER TABLE users ADD COLUMN firebase_id TEXT DEFAULT NULL;

-- Create an index on firebase_id for faster lookups
CREATE INDEX idx_users_firebase_id ON users(firebase_id);

