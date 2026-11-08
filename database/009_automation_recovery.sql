
CREATE OR REPLACE FUNCTION recover_expired_jobs()
RETURNS TABLE (
    recovered_events BIGINT,
    closed_events BIGINT,
    recovered_hubspot_jobs BIGINT,
    closed_hubspot_jobs BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_recovered_events BIGINT;
    v_closed_events BIGINT;
    v_recovered_jobs BIGINT;
    v_closed_jobs BIGINT;
BEGIN
    WITH recovered AS (
        UPDATE source_events
        SET status = 'failed',
            claim_token = NULL,
            lease_expires_at = NULL,
            next_retry_at = NOW(),
            last_error = 'Processing lease expired',
            updated_at = NOW()
        WHERE status = 'processing'
          AND lease_expires_at <= NOW()
          AND attempt_count < 3
        RETURNING id
    )
    SELECT COUNT(*)
    INTO v_recovered_events
    FROM recovered;

    WITH closed AS (
        UPDATE source_events
        SET status = 'failed',
            claim_token = NULL,
            lease_expires_at = NULL,
            next_retry_at = NULL,
            last_error = 'Maximum attempts exhausted',
            updated_at = NOW()
        WHERE status = 'processing'
          AND lease_expires_at <= NOW()
          AND attempt_count >= 3
        RETURNING id, customer_id, attempt_count
    ),
    logged AS (
        INSERT INTO sync_audit_logs (
            source_event_id,
            customer_id,
            action,
            outcome,
            details
        )
        SELECT id, customer_id,
               'event_recovery', 'failed',
               jsonb_build_object(
                   'attempt_count', attempt_count,
                   'reason', 'maximum_attempts'
               )
        FROM closed
        RETURNING id
    )
    SELECT COUNT(*)
    INTO v_closed_events
    FROM logged;

    WITH recovered AS (
        UPDATE hubspot_sync_jobs
        SET status = 'failed',
            claim_token = NULL,
            lease_expires_at = NULL,
            next_retry_at = NOW(),
            last_error = 'HubSpot processing lease expired',
            updated_at = NOW()
        WHERE status = 'processing'
          AND lease_expires_at <= NOW()
          AND attempt_count < 3
        RETURNING id
    )
    SELECT COUNT(*)
    INTO v_recovered_jobs
    FROM recovered;

    WITH closed AS (
        UPDATE hubspot_sync_jobs
        SET status = 'failed',
            claim_token = NULL,
            lease_expires_at = NULL,
            next_retry_at = NULL,
            last_error = 'Maximum attempts exhausted',
            updated_at = NOW()
        WHERE status = 'processing'
          AND lease_expires_at <= NOW()
          AND attempt_count >= 3
        RETURNING id, customer_id, attempt_count
    ),
    logged AS (
        INSERT INTO sync_audit_logs (
            customer_id,
            action,
            outcome,
            details
        )
        SELECT customer_id,
               'hubspot_job_recovery',
               'failed',
               jsonb_build_object(
                   'job_id', id,
                   'attempt_count', attempt_count,
                   'reason', 'maximum_attempts'
               )
        FROM closed
        RETURNING id
    )
    SELECT COUNT(*)
    INTO v_closed_jobs
    FROM logged;

    RETURN QUERY
    SELECT v_recovered_events,
           v_closed_events,
           v_recovered_jobs,
           v_closed_jobs;
END;
$$;
