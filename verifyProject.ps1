param([string]$N8nContainer = 'n8n')
$ErrorActionPreference = 'Continue'
Write-Host '=== Docker containers ==='
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
Write-Host '=== PostgreSQL readiness ==='
docker exec p02-postgres pg_isready -U p02_user -d p02_crm
Write-Host '=== FastAPI health ==='
try { Invoke-RestMethod 'http://localhost:8000/health' | ConvertTo-Json } catch { Write-Warning $_ }
Write-Host '=== n8n HTTP status ==='
try { (Invoke-WebRequest 'http://localhost:5678' -UseBasicParsing).StatusCode } catch { Write-Warning $_ }
Write-Host '=== Event statuses ==='
docker exec p02-postgres psql -U p02_user -d p02_crm -c 'SELECT status, COUNT(*) FROM source_events GROUP BY status ORDER BY status;'
Write-Host '=== HubSpot job statuses ==='
docker exec p02-postgres psql -U p02_user -d p02_crm -c 'SELECT status, COUNT(*) FROM hubspot_sync_jobs GROUP BY status ORDER BY status;'
