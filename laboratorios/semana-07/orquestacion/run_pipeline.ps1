$ErrorActionPreference = "Stop"

# Resolve project paths from the script location.
$LabRoot = Split-Path -Parent $PSScriptRoot
$EnvFile = Join-Path $LabRoot ".env"
$DbtDir = Join-Path $LabRoot "dbt"
$DataDir = Join-Path $LabRoot "data"

Write-Host ""
Write-Host "========================================"
Write-Host " NYC Yellow Taxi ELT Pipeline"
Write-Host "========================================"
Write-Host ""

# ---------------------------------------------------------
# 1. Validate required local configuration
# ---------------------------------------------------------

Write-Host "[1/5] Validating local configuration..."

if (-not (Test-Path $EnvFile)) {
    throw "Missing .env file: $EnvFile"
}

if (-not (Test-Path $DbtDir)) {
    throw "Missing dbt directory: $DbtDir"
}

if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Path $DataDir | Out-Null
}

Write-Host "Configuration OK."

# ---------------------------------------------------------
# 2. Bronze - automatic ingestion
# ---------------------------------------------------------

Write-Host ""
Write-Host "[2/5] Running Bronze ingestion..."

docker run --rm `
    --env-file $EnvFile `
    -e SNOWFLAKE_PRIVATE_KEY_PATH=/keys/rsa_key.p8 `
    -v "${DataDir}:/data" `
    -v "${HOME}/.snowflake:/keys:ro" `
    nyc-taxi-ingestion `
    python ingest.py --all

if ($LASTEXITCODE -ne 0) {
    throw "Bronze ingestion failed."
}

Write-Host "Bronze ingestion completed."

# ---------------------------------------------------------
# 3. Load reference data
# ---------------------------------------------------------

Write-Host ""
Write-Host "[3/5] Loading dbt seeds..."

docker run --rm `
    --env-file $EnvFile `
    -e SNOWFLAKE_PRIVATE_KEY_PATH=/keys/rsa_key.p8 `
    -v "${DbtDir}:/usr/app" `
    -v "${HOME}/.snowflake:/keys:ro" `
    ghcr.io/dbt-labs/dbt-snowflake:latest `
    seed --project-dir /usr/app --profiles-dir /usr/app

if ($LASTEXITCODE -ne 0) {
    throw "dbt seed failed."
}

# ---------------------------------------------------------
# 4. Silver + Gold transformations
# ---------------------------------------------------------

Write-Host ""
Write-Host "[4/5] Building Silver and Gold models..."

docker run --rm `
    --env-file $EnvFile `
    -e SNOWFLAKE_PRIVATE_KEY_PATH=/keys/rsa_key.p8 `
    -v "${DbtDir}:/usr/app" `
    -v "${HOME}/.snowflake:/keys:ro" `
    ghcr.io/dbt-labs/dbt-snowflake:latest `
    run --project-dir /usr/app --profiles-dir /usr/app

if ($LASTEXITCODE -ne 0) {
    throw "dbt run failed."
}

# ---------------------------------------------------------
# 5. Data quality validation
# ---------------------------------------------------------

Write-Host ""
Write-Host "[5/5] Running dbt tests..."

docker run --rm `
    --env-file $EnvFile `
    -e SNOWFLAKE_PRIVATE_KEY_PATH=/keys/rsa_key.p8 `
    -v "${DbtDir}:/usr/app" `
    -v "${HOME}/.snowflake:/keys:ro" `
    ghcr.io/dbt-labs/dbt-snowflake:latest `
    test --project-dir /usr/app --profiles-dir /usr/app

if ($LASTEXITCODE -ne 0) {
    throw "dbt tests failed."
}

Write-Host ""
Write-Host "========================================"
Write-Host " PIPELINE COMPLETED SUCCESSFULLY"
Write-Host " Bronze -> Silver -> Gold"
Write-Host "========================================"