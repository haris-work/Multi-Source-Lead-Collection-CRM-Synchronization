
INSERT INTO source_events (
    source,
    source_event_id,
    customer_email,
    payload,
    status
)
VALUES (
    'external_crm',
    'API-IDENTITY-9001',
    'identity.test@example.com',
    '{
      "source": "external_crm",
      "source_event_id": "API-IDENTITY-9001",
      "customer": {
        "name": "Sarah Johnson",
        "email": "identity.test@example.com",
        "phone": "",
        "company": "BrightPath Solutions"
      },
      "inquiry": {
        "service": "CRM Automation",
        "budget": 5000,
        "message": "Updated external CRM inquiry."
      },
      "metadata": {
        "external_contact_id": "CRM-TEST-9001",
        "event_type": "updated",
        "contact_version": 2
      }
    }'::jsonb,
    'ready'
)
ON CONFLICT (source, source_event_id)
DO NOTHING;
