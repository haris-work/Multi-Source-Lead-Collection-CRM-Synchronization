param([string]$N8nContainer = "n8n")
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

docker info --format '{{.ServerVersion}}' | Out-Null
if ($LASTEXITCODE -ne 0) { throw "Docker Desktop engine is not running." }
$existing = @(docker ps -a --format '{{.Names}}')
if ($existing -notcontains 'p02-postgres') { throw "Existing p02-postgres container not found. Do not create a blank replacement." }
if ($existing -notcontains $N8nContainer) { throw "n8n container '$N8nContainer' not found. Run docker ps -a and pass -N8nContainer ACTUAL_NAME." }

docker start p02-postgres | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Unable to start PostgreSQL' }
docker start $N8nContainer | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'Unable to start n8n' }

docker compose up -d --build external-crm-api
if ($LASTEXITCODE -ne 0) { throw 'FastAPI Compose service failed to start' }
Write-Host "Services requested. Run .\verifyProject.ps1 to inspect readiness."
Write-Host 'n8n: http://localhost:5678 | FastAPI: http://localhost:8000/docs'
