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

$RepoPath = $paramJson.repoRoot
$PushCommands = $paramJson.repoSettings.repoPushCommands

#
# --- EXECUTION ---
#


# -----------------------------------
# --- Resolve path to repo
# -----------------------------------

Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Starting working with the repo..."  -ForegroundColor Cyan

Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Locating repo folder..."  -ForegroundColor Cyan

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$FullRepoPath = if ([System.IO.Path]::IsPathRooted($RepoPath)) { $RepoPath } 
                   else { [System.IO.Path]::GetFullPath((Join-Path $ScriptDir $RepoPath)) }
Write-Host "Full Path to Repo: $FullRepoPath"              

Set-Location $FullRepoPath


# --------------------------------------
# --- Execute git commands
# -----------------------------------

# Function: Git Add
function Invoke-GitAdd {

    $gitAddCommand = "add -A"
    $fullCommand = "git $gitAddCommand"
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $fullCommand"  -ForegroundColor Cyan
    Invoke-Expression $fullCommand | Out-Default
    Write-Host "Changes added to stage."
}

# Function: Git Commit
function Invoke-GitCommit {
    Write-Host "`nEnter commit message: " -NoNewline -ForegroundColor Green
    $commitMessage = Read-Host
    
    if ([string]::IsNullOrWhiteSpace($commitMessage)) {
        Write-Host "Commit message cannot be empty. Operation cancelled."
        return $false
    }
    
    $gitCommitCommand = "commit -m `"$commitMessage`""
    $fullCommand = "git $gitCommitCommand"
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $fullCommand" -ForegroundColor Cyan
    Invoke-Expression $fullCommand | Out-Default
    return $true
}

# Function: Git Push
function Invoke-GitPush {
    # Split the Git commands string by ";"
    $commandArray = $PushCommands -split ';'

    $commandIndex = 0
    foreach ($command in $commandArray) {
        $commandIndex++
        
        # Trim whitespace from the command
        $command = $command.Trim()
        
        # Skip empty commands
        if ([string]::IsNullOrWhiteSpace($command)) {
            continue
        }
        
        # Prepend "git " to the substring to produce $fullCommand
        $fullCommand = "git $command"
        
        # Display the command being executed
        Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $fullCommand" -ForegroundColor Cyan
        
        try {
            # Execute the command
            Invoke-Expression $fullCommand | Out-Default
            
            # Check if the command was successful
            if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
                Write-Host "`nERROR: Command failed with exit code $LASTEXITCODE" -ForegroundColor Red
                Write-Host "Command: $fullCommand" -ForegroundColor Red
                Write-Host "Stopping execution of remaining commands." -ForegroundColor Yellow
                break
            }
            
            Write-Host "[SUCCESS] Command completed successfully" -ForegroundColor Green
            
        } catch {
            Write-Host "`nERROR: Command execution failed" -ForegroundColor Red
            Write-Host "Command: $fullCommand" -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Stopping execution of remaining commands." -ForegroundColor Yellow
            break
        }
    }

}

# Function: Ask for confirmation
function Get-Confirmation {
    param (
        [string]$Message
    )
    Write-Host "`n$Message (Y/N): " -NoNewline -ForegroundColor Green
    $response = Read-Host
    return ($response -eq "Y" -or $response -eq "y")
}

# Function: Git Status
function Invoke-GitStatus {
    $gitStatusCommand = "status"
    $fullCommand = "git $gitStatusCommand"
    Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] $fullCommand " -ForegroundColor Cyan
    Invoke-Expression $fullCommand | Out-Default
}

# Function: Show status and handle user choice
function Invoke-GitWorkflow {

    Invoke-GitStatus

    Write-Host "`nChoose an option:" -ForegroundColor Green
    Write-Host "  A - Add all changes to stage"
    Write-Host "  C - Commit"
    Write-Host "  P - Push"
    Write-Host "  Q - Quit"
    Write-Host "Enter your choice (A/C/P/Q): " -NoNewline
    $response = Read-Host

    switch ($response.ToUpper()) {
        "Q" {
            Write-Host "Quitting..."
            return $false
	}
        "A" {
            Invoke-GitAdd
	    Invoke-GitStatus
            
            if (-not (Get-Confirmation "Proceed with committing?")) {
                Write-Host "Operation cancelled."
                return $true
            }
            
            if (-not (Invoke-GitCommit)) {
                return $true
            }
	    Invoke-GitStatus            
	    
	    Write-Host "`nCommited changes will be pushed using these commands: "
	    Write-Host "  $PushCommands"  -ForegroundColor Yellow
            
	    if (-not (Get-Confirmation "Proceed with pushing?")) {
                Write-Host "Operation cancelled."
                return $true
            }
            
            Invoke-GitPush

            Write-Host "`nAll operations completed successfully!"
	    Invoke-GitStatus 
        }
        "C" {
            if (-not (Invoke-GitCommit)) {
                return $true
            }
	    Invoke-GitStatus
            
	    Write-Host "`nCommited changes will be pushed using these commands: "
	    Write-Host "  $PushCommands"  -ForegroundColor Yellow

            if (-not (Get-Confirmation "Proceed with pushing?")) {
                Write-Host "Operation cancelled."
                return $true
            }
            
            Invoke-GitPush

            Write-Host "`nAll operations completed successfully!"
	    Invoke-GitStatus 
        }
        "P" {
            
	    Write-Host "`nCommited changes will be pushed using these commands: "
	    Write-Host "  $PushCommands"  -ForegroundColor Yellow

            if (-not (Get-Confirmation "Proceed with pushing?")) {
                Write-Host "Operation cancelled."
                return $true
            }

	    Invoke-GitPush
            Write-Host "`nPush completed successfully!"

	    Invoke-GitStatus
        }
        default {
            Write-Host "Invalid option."
            return $true
        }
    }
    
    return $true
}

# Main loop
while ($true) {
    $continue = Invoke-GitWorkflow
    
    if (-not $continue) {
        break
    }
    
    if (-not (Get-Confirmation "Check git status again?")) {
        Write-Host "Done!"
        break
    }

}

Write-Host "`n[$(Get-Date -Format 'HH:mm:ss')] Finished working with the repo.`n"  -ForegroundColor Cyan

# --------------------
# --- Post processing
# --------------------

# Return to the initial location

Set-Location $ScriptDir