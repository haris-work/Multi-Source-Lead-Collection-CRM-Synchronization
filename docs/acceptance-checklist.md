# Project 02 — Acceptance checklist

- [ ] Existing n8n and PostgreSQL containers started, with historical data intact.
- [ ] FastAPI responds at `http://localhost:8000/health`.
- [ ] n8n reaches FastAPI at `http://host.docker.internal:8000/health`.
- [ ] n8n PostgreSQL credential connects to `p02_crm`.
- [ ] All required source and worker workflows are published.
- [ ] Google Sheets OAuth credential is still valid.
- [ ] New row `SHEET-FINAL-001` triggers exactly one new source event.
- [ ] Event moves through `received` to `ready`.
- [ ] Canonical customer is created or correctly matched.
- [ ] One initial HubSpot job reaches `completed` and stores HubSpot ID.
- [ ] Repeat of the same source event is deduplicated.
- [ ] Same email from a second source matches canonical customer.
- [ ] Identity conflicts are reviewed rather than merged automatically.
- [ ] Existing HubSpot field conflicts require manual approval.
- [ ] Error logs and health snapshots are recorded.
- [ ] No credentials or customer data are committed to Git.
