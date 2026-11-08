
CREATE TABLE IF NOT EXISTS system_health_snapshots (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    health_status TEXT NOT NULL,
    metrics JSONB NOT NULL,
    alerts JSONB NOT NULL,
    checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS
    idx_system_health_snapshots_time
ON system_health_snapshots(checked_at DESC);



CREATE TABLE IF NOT EXISTS workflow_error_logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    workflow_id TEXT,
    workflow_name TEXT,
    execution_id TEXT,
    failed_node TEXT,
    error_message TEXT,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS
    idx_workflow_error_execution
ON workflow_error_logs (workflow_id, execution_id)
WHERE execution_id <> '';
