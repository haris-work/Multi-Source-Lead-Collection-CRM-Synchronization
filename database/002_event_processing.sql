
BEGIN;

ALTER TABLE source_events
    ADD COLUMN IF NOT EXISTS claim_token UUID;

ALTER TABLE source_events
    ADD COLUMN IF NOT EXISTS lease_expires_at TIMESTAMPTZ;

ALTER TABLE source_events
    ADD COLUMN IF NOT EXISTS next_retry_at TIMESTAMPTZ;

ALTER TABLE source_events
    DROP CONSTRAINT IF EXISTS source_events_status_check;

ALTER TABLE source_events
    ADD CONSTRAINT source_events_status_check
    CHECK (
        status IN (
            'received',
            'processing',
            'ready',
            'rejected',
            'completed',
            'failed',
            'manual_review'
        )
    );

CREATE INDEX IF NOT EXISTS
    idx_source_events_worker_queue
ON source_events (
    status,
    next_retry_at,
    id
);

COMMIT;
