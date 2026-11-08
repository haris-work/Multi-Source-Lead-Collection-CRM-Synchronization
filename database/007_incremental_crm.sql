
CREATE OR REPLACE FUNCTION ingest_external_crm_batch(
    p_events JSONB
)
RETURNS TABLE (
    inserted_count INTEGER,
    duplicate_count INTEGER,
    rejected_count INTEGER,
    new_cursor BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_cursor BIGINT;
    v_event JSONB;
    v_contact JSONB;
    v_payload JSONB;
    v_errors JSONB;

    v_event_id BIGINT;
    v_email TEXT;
    v_name TEXT;
    v_service TEXT;
    v_budget NUMERIC;

    v_inserted INTEGER := 0;
    v_duplicates INTEGER := 0;
    v_rejected INTEGER := 0;
    v_affected INTEGER;
BEGIN
    IF p_events IS NULL
       OR jsonb_typeof(p_events) <> 'array' THEN
        RAISE EXCEPTION
            'Input must be a JSON array';
    END IF;

    INSERT INTO sync_cursors (
        source, last_event_id
    )
    VALUES ('external_crm_api', '0')
    ON CONFLICT (source) DO NOTHING;

    SELECT last_event_id::BIGINT
    INTO v_cursor
    FROM sync_cursors
    WHERE source = 'external_crm_api'
    FOR UPDATE;

    FOR v_event IN
        SELECT value
        FROM jsonb_array_elements(p_events)
        ORDER BY (value->>'eventId')::BIGINT
    LOOP
        v_event_id := (v_event->>'eventId')::BIGINT;

        IF v_event_id <= v_cursor THEN
            v_duplicates := v_duplicates + 1;
            CONTINUE;
        END IF;

        IF v_event_id <> v_cursor + 1 THEN
            RAISE EXCEPTION
                'Event gap: expected %, received %',
                v_cursor + 1, v_event_id;
        END IF;

        v_contact := v_event->'contact';

        IF jsonb_typeof(v_contact) <> 'object' THEN
            RAISE EXCEPTION
                'Event % missing contact object',
                v_event_id;
        END IF;

        v_email := LOWER(TRIM(
            COALESCE(v_contact->>'email', '')
        ));

        v_name := TRIM(
            CONCAT_WS(
                ' ',
                NULLIF(v_contact->>'firstName', ''),
                NULLIF(v_contact->>'lastName', '')
            )
        );

        v_service := TRIM(
            COALESCE(v_contact->>'service', '')
        );

        v_errors := '[]'::JSONB;

        IF LENGTH(v_name) < 2 THEN
            v_errors := v_errors ||
                '["Invalid customer name"]'::JSONB;
        END IF;

        IF v_email !~
           '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
        THEN
            v_errors := v_errors ||
                '["Invalid email address"]'::JSONB;
        END IF;

        IF v_service = '' THEN
            v_errors := v_errors ||
                '["Service is required"]'::JSONB;
        END IF;

        IF v_contact->'budget' IS NOT NULL
           AND v_contact->'budget' <> 'null'::JSONB
        THEN
            IF jsonb_typeof(v_contact->'budget') <> 'number'
            THEN
                v_errors := v_errors ||
                    '["Invalid budget type"]'::JSONB;
            ELSE
                v_budget := (v_contact->>'budget')::NUMERIC;

                IF v_budget < 0 THEN
                    v_errors := v_errors ||
                        '["Invalid budget"]'::JSONB;
                END IF;
            END IF;
        END IF;

        v_payload := jsonb_build_object(
            'source', 'external_crm',
            'source_event_id', 'API-' || v_event_id,
            'customer', jsonb_build_object(
                'name', v_name,
                'email', v_email,
                'phone', COALESCE(v_contact->>'phone', ''),
                'company', COALESCE(v_contact->>'company', '')
            ),
            'inquiry', jsonb_build_object(
                'service', v_service,
                'budget', v_contact->'budget',
                'message', COALESCE(v_contact->>'message', '')
            ),
            'metadata', jsonb_build_object(
                'external_contact_id', v_event->>'contactId',
                'external_event_id', v_event_id,
                'event_type', v_event->>'eventType',
                'contact_version', v_contact->'version',
                'event_timestamp', v_event->>'createdAt'
            )
        );

        INSERT INTO source_events (
            source,
            source_event_id,
            customer_email,
            event_type,
            payload,
            validation_errors,
            status
        )
        VALUES (
            'external_crm',
            'API-' || v_event_id,
            v_email,
            COALESCE(v_event->>'eventType', 'updated'),
            v_payload,
            v_errors,
            CASE
                WHEN jsonb_array_length(v_errors) = 0
                THEN 'received'
                ELSE 'rejected'
            END
        )
        ON CONFLICT (source, source_event_id)
        DO NOTHING;

        GET DIAGNOSTICS v_affected = ROW_COUNT;

        IF v_affected = 1 THEN
            v_inserted := v_inserted + 1;
        ELSE
            v_duplicates := v_duplicates + 1;
        END IF;

        IF jsonb_array_length(v_errors) > 0 THEN
            v_rejected := v_rejected + 1;
        END IF;

        v_cursor := v_event_id;
    END LOOP;

    UPDATE sync_cursors
    SET
        last_event_id = v_cursor::TEXT,
        updated_at = NOW()
    WHERE source = 'external_crm_api';

    RETURN QUERY
    SELECT
        v_inserted,
        v_duplicates,
        v_rejected,
        v_cursor;
END;
$$;
