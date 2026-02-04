
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
$SourcePath = $paramJson.repoSettings.notebooks.sourcePath
$DestInput = $paramJson.repoSettings.notebooks.destinationPath


#
# --- EXECUTION ---
#

Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Starting syncing..." -ForegroundColor Cyan

# Change the Windows console code page to 65001 (UTF-8)
chcp 65001

#
# --- RESOLVE PATHS ---
#

Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Validating source and destination paths..." -ForegroundColor Cyan

# Resolve Destination to Absolute Path
Write-Host "User-provided Destination Input: $DestInput"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$DestinationPath = if ([System.IO.Path]::IsPathRooted($DestInput)) { $DestInput } 
                   else { [System.IO.Path]::GetFullPath((Join-Path $ScriptDir $DestInput)) }
Write-Host "Full Destination Path: $DestinationPath"              
Write-Host ""

# Validate source path
if (-not (Test-Path $SourcePath)) {
    Write-Error "Source directory doesn't exist: $SourcePath"
    exit 1
} 
else {
    Write-Host "Source directory exists: $SourcePath"
}

# Validate destination path
if (-not (Test-Path $DestinationPath)) {
    Write-Error "Destination directory doesn't exist: $DestinationPath"
    exit 1
} 
else {
    Write-Host "Destination directory exists: $DestinationPath"
}

#
# --- HELPER: STRIP NOTEBOOK ---
#

function Format-Notebook {
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

    # Calculate the count
    $FileCount = 0

    # Parse log for changed files (Regex ensures line starts with trailing spaces and a Date YYYY/MM/DD)
    $ChangedFiles = $RoboLog | Where-Object { $_ -match "^\s*\d{4}/\d{2}/\d{2}" } | ForEach-Object {
            # Remove the timestamp prefix to extract only the Absolute source file path
            $RawPath = $_.Trim() -replace "^\s*\d{4}/\d{2}/\d{2} \d{2}:\d{2}:\d{2}\s+", ""
            $FileNumber = $FileCount+1

            $SourcePathWithSeparator = $SourcePath + "\"
            $DestinationPathWithSeparator = $DestinationPath + "\"
                        
            if ($RawPath.StartsWith($SourcePathWithSeparator)){ 
                # The log lists changed files in the source path

                # Subtract Source path to leave Relative file path only
                $RelativePath = $RawPath.Replace($SourcePath, "").TrimStart("\")
                Write-Host "[$FileNumber] (change) Relative source file path: [$RelativePath]"
            
                # Create absolute destination file path by concatenating Destination Path and Relative file path
                $AbsolutePath = Join-Path $DestinationPath $RelativePath
                Write-Host "  Absolute path destination: [$AbsolutePath]"
            }
            elseif ($RawPath.StartsWith($DestinationPathWithSeparator)) { 
                # The log lists deleted files in the destination path
                $AbsolutePath = $RawPath
                Write-Host "[$FileNumber] (deletion) Absolute path destination: [$AbsolutePath]"
            }

            Write-Host ""

            # Write Destination file path into the collection of Changed files
            $AbsolutePath

            $FileCount++
        }

    
    Write-Host "Finished syncing folders. Files changed: $FileCount."

    $FileCountChanged = 0
    $FileCountDeleted = 0

    # Apply stripping logic to every changed file
    if ($FileCount -gt 0) {
	    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Processing changes..." -ForegroundColor Cyan
            foreach ($File in $ChangedFiles) {
                if (Test-Path $File) {
                    Write-Host "  [+] Cleaning changed file: $(Split-Path $File -Leaf)" -ForegroundColor Yellow
                    Format-Notebook -FilePath $File
                    $FileCountChanged++
                }
                else {
                    Write-Host "  [+] Deleted file: $(Split-Path $File -Leaf)" -ForegroundColor Yellow
                    $FileCountDeleted++
                }
            }
            Write-Host "Done! $FileCountChanged file(s) synced and cleaned. $FileCountDeleted file(s) deleted." -ForegroundColor Yellow
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