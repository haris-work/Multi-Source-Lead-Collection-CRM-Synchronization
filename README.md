# Multi-Source Lead Collection & CRM Synchronization

**Project 02 — AI Automation Engineering Portfolio**

Local automation connecting website/marketing webhooks, Google Sheets, Gmail (Groq-assisted extraction), and an external FastAPI CRM to PostgreSQL and HubSpot through n8n.

## Design

1. n8n source workflows ingest and normalize incoming leads.
2. `SharedLeadProcessor` records events in PostgreSQL with unique `(source, source_event_id)`.
3. Scheduled event and identity workers prepare records and resolve customers.
4. A HubSpot worker searches by email, creates or reuses a contact, and saves its HubSpot ID.
5. Field change proposals require explicit approval; monitoring and recovery workflows report failures.

## Existing-service-safe deployment

This package **does not recreate n8n or PostgreSQL**. It starts the two already-existing containers and runs your existing FastAPI application in Docker Compose. Their volumes and credentials must be preserved. Keep Docker Desktop running.

1. Copy your existing `external-CRM-API/main.py` (and your existing `crm.db` if it exists) into `external-CRM-API/`. Do not overwrite your current `crm.db` with an empty file. For a safer approach, copy the supplied Dockerfile, requirements file and compose.yaml into your existing project directory.
2. Ensure no Windows Uvicorn process is still listening on port 8000.
3. Start with `./startProject.ps1 -N8nContainer ACTUAL_N8N_CONTAINER_NAME`.
4. Check status with `./verifyProject.ps1`.
5. Visit `http://localhost:5678` (n8n) and `http://localhost:8000/docs` (FastAPI).

`compose.yaml` intentionally contains **only** FastAPI. Existing n8n and PostgreSQL installations remain independent.

## n8n workflows

Put your exported and sanitized workflow JSON in `n8nWorkflows/`. Do not assume workflows or credentials are captured just by copying these starter files. A full instance recovery also requires n8n's encrypted data and encryption key.

## API smoke test

`python tests/test_api.py` validates health, create, and update endpoints. It **writes a unique synthetic contact** to the local SQLite CRM; don't run against production.

## End-to-end test

Add an entirely new row to the connected Google Sheets `Leads` tab with ID `SHEET-FINAL-001`, email `final.p02.test@example.com`, name `Jordan Lee`, service `CRM Automation`, budget `2500`. Do not execute downstream workers manually. Confirm `source_events`, `customers`, `hubspot_sync_jobs`, and the HubSpot UI; see `docs/acceptance-checklist.md`.

## Security and limitations

- Use only synthetic test records; do not commit secrets, token-bearing n8n headers, SQLite databases or SQL dumps.
- HTTP nodes with literal `Authorization` headers can leak tokens through exported workflow JSON. Remove these before sharing; prefer credentials.
- n8n/CRM OAuth sessions may need reconnecting; polling is unavailable when local Docker is off.
- Unique event insertions prevent duplicate database rows, but do not provide global exactly-once effects.
- HubSpot field updates are manually approved; source identity collisions and review items need human judgment.
- This is a local development and portfolio system, not a hardened public production deployment.
