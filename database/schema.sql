
CREATE TABLE IF NOT EXISTS customers (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    full_name TEXT NOT NULL,
    primary_email TEXT,
    phone TEXT,
    company TEXT,

    hubspot_contact_id TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS
    idx_customers_primary_email
ON customers (LOWER(primary_email))
WHERE primary_email IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS
    idx_customers_hubspot_contact
ON customers (hubspot_contact_id)
WHERE hubspot_contact_id IS NOT NULL;


CREATE TABLE IF NOT EXISTS customer_identities (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    customer_id BIGINT NOT NULL
        REFERENCES customers(id) ON DELETE CASCADE,

    source TEXT NOT NULL,
    external_contact_id TEXT NOT NULL,

    source_email TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT unique_source_identity
        UNIQUE (source, external_contact_id)
);

CREATE INDEX IF NOT EXISTS
    idx_customer_identities_customer
ON customer_identities(customer_id);


CREATE TABLE IF NOT EXISTS source_events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    source TEXT NOT NULL,
    source_event_id TEXT NOT NULL,

    customer_id BIGINT
        REFERENCES customers(id) ON DELETE SET NULL,

    customer_email TEXT,

    event_type TEXT NOT NULL DEFAULT 'lead_received',

    payload JSONB NOT NULL,

    validation_errors JSONB NOT NULL
        DEFAULT '[]'::jsonb,

    status TEXT NOT NULL DEFAULT 'received'
        CHECK (
            status IN (
                'received',
                'rejected',
                'processing',
                'completed',
                'failed',
                'manual_review'
            )
        ),

    attempt_count INTEGER NOT NULL DEFAULT 0
        CHECK (attempt_count >= 0),

    last_error TEXT,

    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ,

    CONSTRAINT unique_source_event
        UNIQUE (source, source_event_id)
);

CREATE INDEX IF NOT EXISTS
    idx_source_events_status
ON source_events(status);

CREATE INDEX IF NOT EXISTS
    idx_source_events_customer
ON source_events(customer_id);

CREATE INDEX IF NOT EXISTS
    idx_source_events_email
ON source_events(LOWER(customer_email))
WHERE customer_email IS NOT NULL;


CREATE TABLE IF NOT EXISTS sync_cursors (
    source TEXT PRIMARY KEY,

    last_event_id TEXT,
    last_event_timestamp TIMESTAMPTZ,

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


CREATE TABLE IF NOT EXISTS sync_audit_logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    source_event_id BIGINT
        REFERENCES source_events(id) ON DELETE SET NULL,

    customer_id BIGINT
        REFERENCES customers(id) ON DELETE SET NULL,

    action TEXT NOT NULL,
    outcome TEXT NOT NULL,

    details JSONB NOT NULL DEFAULT '{}'::jsonb,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS
    idx_sync_audit_logs_event
ON sync_audit_logs(source_event_id);
