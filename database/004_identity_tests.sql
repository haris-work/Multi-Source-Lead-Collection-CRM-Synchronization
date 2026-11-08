
INSERT INTO source_events (
    source,
    source_event_id,
    customer_email,
    payload,
    status
)
VALUES
(
    'website',
    'WEB-IDENTITY-001',
    'identity.test@example.com',
    '{
      "source": "website",
      "source_event_id": "WEB-IDENTITY-001",
      "customer": {
        "name": "Sarah Johnson",
        "email": "identity.test@example.com",
        "phone": "",
        "company": "BrightPath Solutions"
      },
      "inquiry": {
        "service": "CRM Automation",
        "budget": 3000,
        "message": "Need automation."
      }
    }'::jsonb,
    'ready'
),
(
    'marketing',
    'MKT-IDENTITY-001',
    'identity.test@example.com',
    '{
      "source": "marketing",
      "source_event_id": "MKT-IDENTITY-001",
      "customer": {
        "name": "Sarah Johnson",
        "email": "IDENTITY.TEST@example.com",
        "phone": "",
        "company": "BrightPath Solutions"
      },
      "inquiry": {
        "service": "CRM Automation",
        "budget": 5000,
        "message": "Interested in integration."
      }
    }'::jsonb,
    'ready'
),
(
    'google_sheets',
    'SHEET-IDENTITY-001',
    'identity.test@example.com',
    '{
      "source": "google_sheets",
      "source_event_id": "SHEET-IDENTITY-001",
      "customer": {
        "name": "David Miller",
        "email": "identity.test@example.com",
        "phone": "",
        "company": "Miller Technologies"
      },
      "inquiry": {
        "service": "API Integration",
        "budget": 2000,
        "message": "Need API integration."
      }
    }'::jsonb,
    'ready'
)
ON CONFLICT (source, source_event_id)
DO NOTHING;
