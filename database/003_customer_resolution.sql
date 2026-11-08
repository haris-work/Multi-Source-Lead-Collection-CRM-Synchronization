
CREATE OR REPLACE FUNCTION resolve_next_customer()
RETURNS TABLE (
    event_id BIGINT,
    outcome TEXT,
    resolved_customer_id BIGINT,
    detail TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_event source_events%ROWTYPE;

    v_email TEXT;
    v_name TEXT;
    v_phone TEXT;
    v_company TEXT;

    v_external_id TEXT;
    v_identity_source TEXT;

    v_email_customer BIGINT;
    v_identity_customer BIGINT;
    v_customer_id BIGINT;

    v_existing_name TEXT;
    v_existing_email TEXT;

    v_outcome TEXT;
    v_reason TEXT;
BEGIN
    SELECT e.*
    INTO v_event
    FROM source_events e
    WHERE e.status = 'ready'
      AND e.customer_id IS NULL
    ORDER BY e.id
    FOR UPDATE SKIP LOCKED
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    v_email := LOWER(TRIM(
        COALESCE(v_event.payload #>>
            '{customer,email}', '')
    ));

    v_name := TRIM(
        COALESCE(v_event.payload #>>
            '{customer,name}', '')
    );

    v_phone := NULLIF(TRIM(
        COALESCE(v_event.payload #>>
            '{customer,phone}', '')
    ), '');

    v_company := NULLIF(TRIM(
        COALESCE(v_event.payload #>>
            '{customer,company}', '')
    ), '');

    v_external_id := NULLIF(TRIM(
        COALESCE(v_event.payload #>>
            '{metadata,external_contact_id}', '')
    ), '');

    -- Distinguish our custom CRM API from the
    -- earlier external CRM webhook.
    IF v_event.source = 'external_crm'
       AND v_external_id IS NOT NULL THEN

        IF v_event.source_event_id LIKE 'API-%' THEN
            v_identity_source := 'external_crm_api';
        ELSE
            v_identity_source := 'external_crm_webhook';
        END IF;
    END IF;

    -- Check the payload again before matching.
    IF v_email = ''
       OR v_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
       OR LENGTH(v_name) < 2 THEN

        UPDATE source_events e
        SET status = 'manual_review',
            last_error = 'Missing or invalid identity fields',
            updated_at = NOW()
        WHERE e.id = v_event.id;

        INSERT INTO sync_audit_logs (
            source_event_id, action, outcome, details
        )
        VALUES (
            v_event.id,
            'resolve_customer',
            'manual_review',
            jsonb_build_object(
                'reason', 'Invalid identity fields'
            )
        );

        RETURN QUERY SELECT
            v_event.id,
            'manual_review'::text,
            NULL::bigint,
            'Invalid identity fields'::text;

        RETURN;
    END IF;

    -- Serialize resolution of the same email
    -- across concurrent executions.
    PERFORM pg_advisory_xact_lock(
        hashtextextended(v_email, 0)
    );

    SELECT c.id, c.full_name, c.primary_email
    INTO v_email_customer,
         v_existing_name,
         v_existing_email
    FROM customers c
    WHERE LOWER(c.primary_email) = v_email
    FOR UPDATE;

    IF v_external_id IS NOT NULL
       AND v_identity_source IS NOT NULL THEN

        SELECT ci.customer_id
        INTO v_identity_customer
        FROM customer_identities ci
        WHERE ci.source = v_identity_source
          AND ci.external_contact_id = v_external_id
        FOR UPDATE;
    END IF;

    -- Existing external ID points to a different
    -- customer than the email lookup.
    IF v_identity_customer IS NOT NULL
       AND v_email_customer IS NOT NULL
       AND v_identity_customer <> v_email_customer THEN

        v_reason := 'External identity and email belong to different customers';

    ELSIF v_identity_customer IS NOT NULL
          AND v_email_customer IS NULL THEN

        -- Do not silently reassign an existing
        -- external identity to a changed email.
        v_reason := 'Known external identity has a different primary email';

    ELSIF v_email_customer IS NOT NULL
          AND LOWER(
              REGEXP_REPLACE(
                  TRIM(v_existing_name),
                  '[[:space:]]+', ' ', 'g'
              )
          ) <>
          LOWER(
              REGEXP_REPLACE(
                  v_name,
                  '[[:space:]]+', ' ', 'g'
              )
          ) THEN

        v_reason := 'Customer name conflicts with existing email identity';

    END IF;

    IF v_reason IS NOT NULL THEN
        UPDATE source_events e
        SET status = 'manual_review',
            last_error = v_reason,
            updated_at = NOW()
        WHERE e.id = v_event.id;

        INSERT INTO sync_audit_logs (
            source_event_id, action, outcome, details
        )
        VALUES (
            v_event.id,
            'resolve_customer',
            'manual_review',
            jsonb_build_object(
                'reason', v_reason,
                'email', v_email,
                'external_contact_id', v_external_id
            )
        );

        RETURN QUERY SELECT
            v_event.id,
            'manual_review'::text,
            NULL::bigint,
            v_reason;

        RETURN;
    END IF;

    IF v_email_customer IS NOT NULL THEN
        v_customer_id := v_email_customer;
        v_outcome := 'matched';

    ELSE
        INSERT INTO customers (
            full_name,
            primary_email,
            phone,
            company
        )
        VALUES (
            v_name,
            v_email,
            v_phone,
            v_company
        )
        RETURNING id INTO v_customer_id;

        v_outcome := 'created';
    END IF;

    -- Only create external identity links when
    -- the source supplies a stable contact ID.
    IF v_external_id IS NOT NULL
       AND v_identity_source IS NOT NULL THEN

        INSERT INTO customer_identities (
            customer_id,
            source,
            external_contact_id,
            source_email
        )
        VALUES (
            v_customer_id,
            v_identity_source,
            v_external_id,
            v_email
        )
        ON CONFLICT (source, external_contact_id)
        DO NOTHING;

        -- Confirm the identity was not linked
        -- to another customer concurrently.
        SELECT ci.customer_id
        INTO v_identity_customer
        FROM customer_identities ci
        WHERE ci.source = v_identity_source
          AND ci.external_contact_id = v_external_id;

        IF v_identity_customer <> v_customer_id THEN
            RAISE EXCEPTION
                'Concurrent external identity conflict';
        END IF;
    END IF;

    UPDATE source_events e
    SET customer_id = v_customer_id,
        last_error = NULL,
        updated_at = NOW()
    WHERE e.id = v_event.id;

    INSERT INTO sync_audit_logs (
        source_event_id,
        customer_id,
        action,
        outcome,
        details
    )
    VALUES (
        v_event.id,
        v_customer_id,
        'resolve_customer',
        v_outcome,
        jsonb_build_object(
            'email', v_email,
            'source', v_event.source,
            'external_contact_id', v_external_id
        )
    );

    RETURN QUERY SELECT
        v_event.id,
        v_outcome,
        v_customer_id,
        'Customer identity resolved'::text;
END;
$$;
