param([string]$N8nContainer = "n8n")
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
docker compose stop external-crm-api
docker stop $N8nContainer p02-postgres
Write-Host 'Services stopped. Database volume and API files are retained.'
