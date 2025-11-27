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
