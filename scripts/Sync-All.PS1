#
# --- CONFIGURATION ---
#

# Set a path to parameters
param (
    [Alias("p")][string]$paramPath
)

# Default to "../config/_Params-Working-Repo.json" if not provided
if (-not $paramPath) {
    $paramPath = Join-Path -Path $PSScriptRoot -ChildPath "../config/_Params-Working-Repo.json"
}

# Check if parameter file exists
if (-not (Test-Path $paramPath)) {
    Write-Error "Parameter file not found at: $paramPath"
    exit 1
}

$paramJson = Get-Content $paramPath -Raw | ConvertFrom-Json
$RepoType = $paramJson.repoSettings.repoType


#
# --- EXECUTION ---
#

# Sync notebooks
if($RepoType -eq "notebooks"){
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Syncing notebooks" -ForegroundColor Cyan
    Write-Host "========================================`n" -ForegroundColor Cyan
    . .\Sync-Notebooks.PS1 -paramPath $paramPath
}

# Review and sync repo
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Reviewing and syncing repo" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan
. .\Sync-Repo.PS1 -paramPath $paramPath





