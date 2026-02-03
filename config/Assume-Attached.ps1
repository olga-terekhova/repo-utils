# Assume-Attached.ps1
# Configures the instance as a companion attached to a host repository
# This script:
# 1. Sets instanceType to "companion" in _Params-Instance-Repo.json
# 2. Validates both instance and host repository paths
# 3. Creates _Params-Working-Repo.json pointing to the host repository
# 4. Adds companion repository to host's .git/info/exclude

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Assume-Attached Configuration" -ForegroundColor Cyan
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

function Get-RelativePath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,
        
        [Parameter(Mandatory=$true)]
        [string]$To
    )
    
    try {
        # Use .NET's GetRelativePath method (requires PowerShell Core 6.0+ / .NET Core 2.0+)
        # This handles cross-platform paths correctly
        $relativePath = [System.IO.Path]::GetRelativePath($From, $To)
        return $relativePath
    } catch {
        # Fallback: manual calculation for Windows PowerShell 5.1 and earlier
        # (which use .NET Framework instead of .NET Core)
        Write-Host "  [WARNING] Using fallback relative path calculation (Windows PowerShell 5.1 detected)" -ForegroundColor Yellow
        
        # Normalize paths
        $fromNormalized = [System.IO.Path]::GetFullPath($From).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
        $toNormalized = [System.IO.Path]::GetFullPath($To).TrimEnd([System.IO.Path]::DirectorySeparatorChar)
        
        # Split into parts
        $fromParts = $fromNormalized -split [regex]::Escape([System.IO.Path]::DirectorySeparatorChar)
        $toParts = $toNormalized -split [regex]::Escape([System.IO.Path]::DirectorySeparatorChar)
        
        # Find common path length
        $commonLength = 0
        $minLength = [Math]::Min($fromParts.Length, $toParts.Length)
        
        for ($i = 0; $i -lt $minLength; $i++) {
            if ($fromParts[$i] -eq $toParts[$i]) {
                $commonLength++
            } else {
                break
            }
        }
        
        # Build relative path
        $upLevels = $fromParts.Length - $commonLength
        $relativeParts = @()
        
        for ($i = 0; $i -lt $upLevels; $i++) {
            $relativeParts += ".."
        }
        
        for ($i = $commonLength; $i -lt $toParts.Length; $i++) {
            $relativeParts += $toParts[$i]
        }
        
        if ($relativeParts.Length -eq 0) {
            return "."
        }
        
        return $relativeParts -join [System.IO.Path]::DirectorySeparatorChar
    }
}

function Format-GitIgnorePattern {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RelativePath
    )
    
    # Convert to forward slashes (git convention)
    $pattern = $RelativePath -replace '\\', '/'
    
    # Remove leading './' if present
    $pattern = $pattern -replace '^\./', ''
    
    # Handle current directory case
    if ($pattern -eq '.') {
        Write-Host "  [WARNING] Instance and host appear to be in the same directory" -ForegroundColor Yellow
        return $null
    }
    
    # Add trailing slash to indicate directory
    if (-not $pattern.EndsWith('/')) {
        $pattern += '/'
    }
    
    return $pattern
}

function Add-GitExcludePattern {
    param(
        [Parameter(Mandatory=$true)]
        [string]$HostRepoPath,
        
        [Parameter(Mandatory=$true)]
        [string]$Pattern
    )
    
    Write-Host "Configuring git exclude for companion repository..." -ForegroundColor Yellow
    Write-Host "  Pattern: $Pattern" -ForegroundColor Gray
    
    # Construct path to exclude file
    $excludeFilePath = Join-Path $HostRepoPath ".git"
    $excludeFilePath = Join-Path $excludeFilePath "info"
    $excludeDir = $excludeFilePath
    $excludeFilePath = Join-Path $excludeFilePath "exclude"
    
    try {
        # Create .git/info directory if it doesn't exist
        if (-not (Test-Path $excludeDir)) {
            Write-Host "  Creating .git/info directory..." -ForegroundColor Gray
            New-Item -ItemType Directory -Path $excludeDir -Force | Out-Null
            Write-Host "  [OK] Created directory" -ForegroundColor Green
        }
        
        # Check if exclude file exists and read content
        $existingContent = ""
        $patternExists = $false
        
        if (Test-Path $excludeFilePath) {
            $existingContent = Get-Content $excludeFilePath -Raw -ErrorAction Stop
            
            # Check for pattern variations
            $patternVariations = @(
                $Pattern,
                $Pattern.TrimEnd('/'),
                "/$Pattern",
                "./$Pattern",
                "./$($Pattern.TrimEnd('/'))"
            )
            
            foreach ($variation in $patternVariations) {
                # Check each line for matches (case-insensitive on Windows, sensitive on Linux)
                $lines = $existingContent -split "`n"
                foreach ($line in $lines) {
                    $trimmedLine = $line.Trim()
                    if ($trimmedLine -eq $variation) {
                        $patternExists = $true
                        break
                    }
                }
                if ($patternExists) { break }
            }
        }
        
        if ($patternExists) {
            Write-Host "  [SKIP] Pattern already exists in exclude file" -ForegroundColor Cyan
            Write-Host ""
            return $true
        }
        
        # Prepare content to append
        $newContent = ""
        
        # If file doesn't exist or is empty, add header comment
        if ([string]::IsNullOrWhiteSpace($existingContent)) {
            $newContent = "# Git exclude patterns for this repository`n"
            $newContent += "# Added by Assume-Attached.ps1`n`n"
        } else {
            # Ensure existing content ends with newline
            if (-not $existingContent.EndsWith("`n")) {
                $newContent = "`n"
            }
        }
        
        # Add pattern with comment
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $newContent += "# Companion repository (added $timestamp)`n"
        $newContent += "$Pattern`n"
        
        # Write to file
        if ([string]::IsNullOrWhiteSpace($existingContent)) {
            # Create new file
            $newContent | Set-Content -Path $excludeFilePath -NoNewline -Encoding UTF8 -ErrorAction Stop
        } else {
            # Append to existing file
            Add-Content -Path $excludeFilePath -Value $newContent -NoNewline -Encoding UTF8 -ErrorAction Stop
        }
        
        Write-Host "  [OK] Added exclusion pattern to .git/info/exclude" -ForegroundColor Green
        Write-Host ""
        return $true
        
    } catch {
        Write-Host "  [WARNING] Failed to update git exclude file" -ForegroundColor Yellow
        Write-Host "  Reason: $($_.Exception.Message)" -ForegroundColor Gray
        Write-Host "  This is non-critical - configuration will continue" -ForegroundColor Gray
        Write-Host ""
        return $false
    }
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

# Set instanceType to "companion"
$instanceJson.instanceType = "companion"

# Save back to the file
try {
    $instanceJson | ConvertTo-Json -Depth 10 | Set-Content $instanceJsonPath
    Write-Host "Updated instanceType to 'companion' in $instanceJsonPath" -ForegroundColor Green
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
# --- Validate host repository path
# --------------------------------------------------

# Resolve hostRepoRoot to absolute path
$hostRepoAbsolute = Get-AbsolutePath -Path $instanceJson.hostRepoRoot

# Validate host repository
if (-not (Test-GitRepository -Path $hostRepoAbsolute -RepoName "Host Repository")) {
    Write-Host "Failed to validate host repository at: $hostRepoAbsolute" -ForegroundColor Red
    exit 1
}

# --------------------------------------------------
# --- Read _Params-Host-Repo.json
# --------------------------------------------------

$hostJsonPath = "_Params-Host-Repo.json"

# Check if the file exists
if (-not (Test-Path $hostJsonPath)) {
    Write-Host "Error: Configuration file not found: $hostJsonPath" -ForegroundColor Red
    exit 1
}

# Read the JSON file
try {
    $hostJson = Get-Content $hostJsonPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "Error: Failed to read or parse JSON file: $hostJsonPath" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# --------------------------------------------------
# --- Create and save _Params-Working-Repo.json
# --------------------------------------------------

# Create workingJson object
$workingJson = @{
    repoType = $hostJson.repoType
    repoPush = $hostJson.repoPush
    repoRoot = $hostRepoAbsolute
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
# --- Configure Git Exclude for Companion Repository
# --------------------------------------------------

# Calculate relative path from host to instance
$companionRepoRelative = Get-RelativePath -From $hostRepoAbsolute -To $instanceRepoAbsolute

# Format for .gitignore convention
$companionRepoRelativeFormatted = Format-GitIgnorePattern -RelativePath $companionRepoRelative

# Add to git exclude if valid pattern
if ($null -ne $companionRepoRelativeFormatted) {
    Add-GitExcludePattern -HostRepoPath $hostRepoAbsolute -Pattern $companionRepoRelativeFormatted | Out-Null
}

# --------------------------------------------------
# --- Display summary
# --------------------------------------------------

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Configuration Summary" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Instance Type: companion" -ForegroundColor Yellow
Write-Host ""
Write-Host "Instance Repository:" -ForegroundColor Yellow
Write-Host "  Path: $instanceRepoAbsolute" -ForegroundColor Gray
Write-Host ""
Write-Host "Host Repository:" -ForegroundColor Yellow
Write-Host "  Path: $hostRepoAbsolute" -ForegroundColor Gray
Write-Host ""
Write-Host "Working Repository (points to Host):" -ForegroundColor Yellow
Write-Host "  Type: $($workingJson.repoType)" -ForegroundColor Gray
Write-Host "  Root: $($workingJson.repoRoot)" -ForegroundColor Gray
Write-Host "  Push: $($workingJson.repoPush)" -ForegroundColor Gray
Write-Host ""
if ($null -ne $companionRepoRelativeFormatted) {
    Write-Host "Git Exclude Configuration:" -ForegroundColor Yellow
    Write-Host "  Pattern: $companionRepoRelativeFormatted" -ForegroundColor Gray
    Write-Host "  Location: .git/info/exclude" -ForegroundColor Gray
    Write-Host ""
}
Write-Host "Configuration complete!" -ForegroundColor Green
Write-Host ""