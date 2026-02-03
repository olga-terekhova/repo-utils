# Assume-Detached.ps1
# Configures the instance as a standalone repository
# This script:
# 1. Sets instanceType to "standalone" in _Params-Instance-Repo.json
# 2. Validates the instance repository path
# 3. Creates _Params-Working-Repo.json pointing to the instance repository

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Assume-Detached Configuration" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# --------------------------------------------------
# --- HELPER FUNCTIONS
# --------------------------------------------------

function Get-AbsolutePath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [string]$BasePath
    )
    
    # If no BasePath provided, use the script's directory
    if (-not $BasePath) {
        $BasePath = $PSScriptRoot
        if (-not $BasePath) {
            # Fallback to current location
            $BasePath = Get-Location
        }
    }
    
    # Check if the path is absolute or relative
    if ([System.IO.Path]::IsPathRooted($Path)) {
        # It's already an absolute path
        return $Path
    } else {
        # It's a relative path - resolve it relative to the base path
        $absolutePath = Join-Path $BasePath $Path
        $absolutePath = [System.IO.Path]::GetFullPath($absolutePath)
        return $absolutePath
    }
}

function Test-GitRepository {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [string]$RepoName = "Repository"
    )
    
    Write-Host "Validating $RepoName..." -ForegroundColor Yellow
    Write-Host "  Path: $Path" -ForegroundColor Gray
    
    # Check if the path exists
    if (-not (Test-Path $Path)) {
        Write-Host "  [ERROR] Path does not exist" -ForegroundColor Red
        Write-Host ""
        return $false
    }
    Write-Host "  [OK] Path exists" -ForegroundColor Green
    
    # Check if it's a valid git repository
    $gitDir = Join-Path $Path ".git"
    if (-not (Test-Path $gitDir)) {
        Write-Host "  [ERROR] Not a valid git repository (.git directory not found)" -ForegroundColor Red
        Write-Host ""
        Write-Host "  Please either:" -ForegroundColor Yellow
        Write-Host "    1. Initialize a git repository: git init" -ForegroundColor Yellow
        Write-Host "    2. Update the path in _Params-Instance-Repo.json" -ForegroundColor Yellow
        Write-Host ""
        return $false
    }
    Write-Host "  [OK] Valid git repository" -ForegroundColor Green
    Write-Host ""
    
    return $true
}

# --------------------------------------------------
# --- Read and update _Params-Instance-Repo.json
# --------------------------------------------------

$instanceJsonPath = "_Params-Instance-Repo.json"

# Check if the file exists
if (-not (Test-Path $instanceJsonPath)) {
    Write-Host "Error: Configuration file not found: $instanceJsonPath" -ForegroundColor Red
    exit 1
}

# Read the JSON file
try {
    $instanceJson = Get-Content $instanceJsonPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "Error: Failed to read or parse JSON file: $instanceJsonPath" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Set instanceType to "standalone"
$instanceJson.instanceType = "standalone"

# Save back to the file
try {
    $instanceJson | ConvertTo-Json -Depth 10 | Set-Content $instanceJsonPath
    Write-Host "Updated instanceType to 'standalone' in $instanceJsonPath" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "Error: Failed to save updated instance configuration" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# --------------------------------------------------
# --- Validate instance repository path
# --------------------------------------------------

# Resolve instanceRepoRoot to absolute path
$instanceRepoAbsolute = Get-AbsolutePath -Path $instanceJson.instanceRepoRoot

# Validate instance repository
if (-not (Test-GitRepository -Path $instanceRepoAbsolute -RepoName "Instance Repository")) {
    Write-Host "Failed to validate instance repository at: $instanceRepoAbsolute" -ForegroundColor Red
    exit 1
}

# --------------------------------------------------
# --- Create and save _Params-Working-Repo.json
# --------------------------------------------------

# Create workingJson object
$workingJson = @{
    repoType = $instanceJson.repoType
    repoPush = $instanceJson.repoPush
    repoRoot = $instanceRepoAbsolute
}

# Save to _Params-Working-Repo.json
$workingJsonPath = "_Params-Working-Repo.json"

try {
    $workingJson | ConvertTo-Json -Depth 10 | Set-Content $workingJsonPath
    Write-Host "Created working repository configuration: $workingJsonPath" -ForegroundColor Green
    Write-Host ""
} catch {
    Write-Host "Error: Failed to save working repository configuration" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# --------------------------------------------------
# --- Display summary
# --------------------------------------------------

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Configuration Summary" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Instance Type: standalone" -ForegroundColor Yellow
Write-Host ""
Write-Host "Instance Repository:" -ForegroundColor Yellow
Write-Host "  Path: $instanceRepoAbsolute" -ForegroundColor Gray
Write-Host ""
Write-Host "Working Repository (points to Instance):" -ForegroundColor Yellow
Write-Host "  Type: $($workingJson.repoType)" -ForegroundColor Gray
Write-Host "  Root: $($workingJson.repoRoot)" -ForegroundColor Gray
Write-Host "  Push: $($workingJson.repoPush)" -ForegroundColor Gray
Write-Host ""
Write-Host "Configuration complete!" -ForegroundColor Green
Write-Host ""
