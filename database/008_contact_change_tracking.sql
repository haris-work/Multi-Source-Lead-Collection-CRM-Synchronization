
BEGIN;

CREATE TABLE IF NOT EXISTS contact_change_proposals (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    source_event_id BIGINT NOT NULL
        REFERENCES source_events(id),

    customer_id BIGINT NOT NULL
        REFERENCES customers(id),

    field_name TEXT NOT NULL
        CHECK (field_name IN ('phone', 'company')),

    current_value TEXT,
    proposed_value TEXT NOT NULL,

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'approved',
                'rejected',
                'applied',
                'conflict'
            )
        ),

    reviewed_at TIMESTAMPTZ,
    applied_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (source_event_id, field_name)
);

CREATE INDEX IF NOT EXISTS
    idx_contact_change_proposals_status
ON contact_change_proposals(status);

COMMIT;
