
BEGIN;

CREATE TABLE IF NOT EXISTS hubspot_sync_jobs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    customer_id BIGINT NOT NULL
        REFERENCES customers(id) ON DELETE CASCADE,

    status TEXT NOT NULL DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'processing',
                'completed',
                'failed'
            )
        ),

    attempt_count INTEGER NOT NULL DEFAULT 0,

    claim_token UUID,
    lease_expires_at TIMESTAMPTZ,
    next_retry_at TIMESTAMPTZ,

    hubspot_contact_id TEXT,
    last_error TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,

    CONSTRAINT unique_hubspot_job_customer
        UNIQUE (customer_id)
);

CREATE INDEX IF NOT EXISTS
    idx_hubspot_sync_jobs_status
ON hubspot_sync_jobs (
    status,
    next_retry_at,
    id
);

COMMIT;
