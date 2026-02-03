
#
# --- CONFIGURATION ---
#

# Set a path to parameters
param (
    [Alias("p")][string]$paramPath
)

# Default to ./Params.ps1 if not provided
if (-not $paramPath) {
    $paramPath = Join-Path -Path $PSScriptRoot -ChildPath "_Params-Sync-Notebooks.ps1"
}

# Check if parameter file exists
if (-not (Test-Path $paramPath)) {
    Write-Error "Parameter file not found at: $paramPath"
    exit 1
}

# Source the parameter file to get $SourcePath, $DestInput
. $paramPath

# Ensure variables are set
if (-not ($SourcePath -and $DestInput)) {
    Write-Error "One or more required parameters are missing in $paramPath"
    exit 1
}

#
# --- EXECUTION ---
#

Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Starting syncing..." -ForegroundColor Cyan

# Change the Windows console code page to 65001 (UTF-8)
chcp 65001

#
# --- RESOLVE PATHS ---
#

Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Checking for changes in Google Drive..." -ForegroundColor Cyan
Write-Host "Google Drive Source Path: $SourcePath"

# Resolve Destination to Absolute Path
Write-Host "User-provided Destination Input: $DestInput"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DestinationPath = if ([System.IO.Path]::IsPathRooted($DestInput)) { $DestInput } 
                   else { [System.IO.Path]::GetFullPath((Join-Path $ScriptDir $DestInput)) }
Write-Host "Full Destination Path: $DestinationPath"              


#
# --- HELPER: STRIP NOTEBOOK ---
#

function Strip-Notebook {
    param ([string]$FilePath)
    try {
        # Read JSON and reset outputs/execution counts
        $notebook = Get-Content -Path $FilePath -Raw -Encoding UTF8 | ConvertFrom-Json
        foreach ($cell in $notebook.cells) {
            if ($cell.cell_type -eq "code") {
                $cell.outputs = @()
                $cell.execution_count = $null
            }
        }
        # Save back with Depth 100 to prevent data loss
        $notebook | ConvertTo-Json -Depth 100 | Set-Content -Path $FilePath -Encoding UTF8
    } catch {
        Write-Host "  [!] Error stripping $FilePath. File might be open or corrupted." -ForegroundColor Red
    }
}

# --- SYNC LOGIC --- 

$SyncLogic ={
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Syncing..." -ForegroundColor Cyan

    # Robocopy with Full Safety Specs:
    # /MIR: Mirror | /XO: Exclude Older | /Z: Restartable
    # /W:5 /R:2: Retries & Wait | /XD: Ignore checkpoints
    # /NJH /NJS /NS /NC /NDL /TS: Logging for parsing
    $RoboLog = robocopy "$SourcePath" "$DestinationPath" *.ipynb /MIR /XO /Z /W:5 /R:2 /XD ".ipynb_checkpoints" /NJH /NJS /NS /NC /NDL /TS
    
    # Parse log for changed files (Regex ensures line starts with trailing spaces and a Date YYYY/MM/DD)
    $ChangedFiles = $RoboLog | Where-Object { $_ -match "^\s*\d{4}/\d{2}/\d{2}" } | ForEach-Object {
            # Remove the timestamp prefix to extract only the Absolute source file path
            $RawPath = $_.Trim() -replace "^\s*\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}\s+", ""
            Write-Host "Raw path: [$RawPath]"
            
            # Subtract Source path to leave Relative file path only
            $RelativePath = $RawPath.Replace($SourcePath, "").TrimStart("\")
            Write-Host "Relative path: [$RelativePath]"
            
            # Create absolute destination file path by concatenating Destination Path and Relative file path
            $AbsolutePath = Join-Path $DestinationPath $RelativePath
            Write-Host "Absolute path: [$AbsolutePath]"

            # Write Destination file path into the collection of Changed files
            $AbsolutePath
        }

    # Calculate the count
    $FileCount = 0
    if ($null -ne $ChangedFiles) {
        # Handle cases where $ChangedFiles might be a single string instead of an array
        $FileCount = @($ChangedFiles).Count
    }
    
    Write-Host "Finished syncing folders. Files changed: $FileCount."

    # Apply stripping logic to every changed file
    if ($FileCount -gt 0) {
	    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Cleaning changed files..." -ForegroundColor Cyan
            foreach ($File in $ChangedFiles) {
                if (Test-Path $File) {
                    Write-Host "  [+] Cleaning: $(Split-Path $File -Leaf)" -ForegroundColor Yellow
                    Strip-Notebook -FilePath $File
                }
            }
            Write-Host "Done! $FileCount file(s) synced and cleaned." -ForegroundColor Yellow
        } else {
            Write-Host "No changes detected. Everything is up to date." -ForegroundColor Yellow
        }

}

#
# --- INITIALIZATION ---
#


# Perform one full sync on startup
& $SyncLogic



Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Finished syncing and cleaning. `n" -ForegroundColor Cyan