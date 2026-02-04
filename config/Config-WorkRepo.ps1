# Config-WorkRepo.ps1
# Interactive configuration editor for working repository settings

#region Helper Functions

function Show-CurrentConfiguration {
    param (
        [string]$InstanceType,
        [string]$RepoRoot,
        [PSCustomObject]$RepoSettings
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Current Working Repository Configuration" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "`nRepository Root: " -NoNewline
    Write-Host $RepoRoot -ForegroundColor Green
    
    if ($InstanceType -eq "standalone") {
        Write-Host "Working repository points to: " -NoNewline
        Write-Host "Instance (standalone mode)" -ForegroundColor Green
    } elseif ($InstanceType -eq "companion") {
        Write-Host "Working repository points to: " -NoNewline
        Write-Host "Host (companion mode)" -ForegroundColor Green
    }
    
    Write-Host "`nRepository Settings:" -ForegroundColor Cyan
    Write-Host "  Repository Type: " -NoNewline
    Write-Host $RepoSettings.repoType -ForegroundColor Yellow
    
    Write-Host "  Push Commands: " -NoNewline
    if ([string]::IsNullOrWhiteSpace($RepoSettings.repoPushCommands)) {
        Write-Host "(not set)" -ForegroundColor Gray
    } else {
        Write-Host $RepoSettings.repoPushCommands -ForegroundColor Yellow
    }
    
    Write-Host "  Init Commands: " -NoNewline
    if ([string]::IsNullOrWhiteSpace($RepoSettings.initGitCommands)) {
        Write-Host "(not set)" -ForegroundColor Gray
    } else {
        Write-Host $RepoSettings.initGitCommands -ForegroundColor Yellow
    }
    
    Write-Host "`n  Notebooks Configuration:" -ForegroundColor Cyan
    Write-Host "    Source Path: " -NoNewline
    if ([string]::IsNullOrWhiteSpace($RepoSettings.notebooks.sourcePath)) {
        Write-Host "(not set)" -ForegroundColor Gray
    } else {
        Write-Host $RepoSettings.notebooks.sourcePath -ForegroundColor Yellow
    }
    
    Write-Host "    Destination Path: " -NoNewline
    if ([string]::IsNullOrWhiteSpace($RepoSettings.notebooks.destinationPath)) {
        Write-Host "(not set)" -ForegroundColor Gray
    } else {
        Write-Host $RepoSettings.notebooks.destinationPath -ForegroundColor Yellow
    }
    
    Write-Host ""
}

function Show-Menu {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Choose an option to edit working repository settings" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "1: Edit the type of the repository"
    Write-Host "2: Edit git commands to be used for pushing the repository"
    Write-Host "3: Edit parameters for notebooks"
    Write-Host "4: Edit git commands to initialize a repository"
    Write-Host "0: Quit"
    Write-Host ""
}

function Edit-RepositoryType {
    param (
        [ref]$WorkingConfig,
        [ref]$PersistentConfig,
        [string]$WorkingConfigPath,
        [string]$PersistentConfigPath
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Edit Repository Type" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "`nCurrent repository type: " -NoNewline
    Write-Host $WorkingConfig.Value.repoSettings.repoType -ForegroundColor Yellow
    
    Write-Host "`nChoose the type of the working repository:"
    Write-Host "1: Regular repository"
    Write-Host "2: Repository with Colab notebooks"
    Write-Host ""
    
    $choice = Read-Host "Enter your choice (1 or 2)"
    
    switch ($choice) {
        "1" {
            $newRepoType = "regular"
            Write-Host "`nSetting repository type to: " -NoNewline
            Write-Host "regular" -ForegroundColor Green
        }
        "2" {
            $newRepoType = "notebooks"
            Write-Host "`nSetting repository type to: " -NoNewline
            Write-Host "notebooks" -ForegroundColor Green
        }
        default {
            Write-Host "`nInvalid choice. Repository type not changed." -ForegroundColor Yellow
            return
        }
    }
    
    # Update the repoType in both configurations
    $WorkingConfig.Value.repoSettings.repoType = $newRepoType
    $PersistentConfig.Value.repoSettings.repoType = $newRepoType
    
    # Save to working config file
    try {
        $WorkingConfig.Value | ConvertTo-Json -Depth 10 | Set-Content -Path $WorkingConfigPath -Encoding UTF8
        Write-Host "Updated: " -NoNewline
        Write-Host $WorkingConfigPath -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to save working configuration" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return
    }
    
    # Save to persistent config file
    try {
        $PersistentConfig.Value | ConvertTo-Json -Depth 10 | Set-Content -Path $PersistentConfigPath -Encoding UTF8
        Write-Host "Updated: " -NoNewline
        Write-Host $PersistentConfigPath -ForegroundColor Green
    } catch {
        Write-Host "ERROR: Failed to save persistent configuration" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return
    }
    
    Write-Host "`nRepository type successfully updated to: " -NoNewline
    Write-Host $newRepoType -ForegroundColor Green
    
    # If notebooks type was chosen, offer to configure notebooks parameters
    if ($newRepoType -eq "notebooks") {
        Write-Host ""
        $proceedToNotebooks = Read-Host "Proceed to setting up notebooks parameters? (Y/N)"
        
        if ($proceedToNotebooks -match "^[Yy]") {
            Edit-NotebooksParameters -WorkingConfig $WorkingConfig -PersistentConfig $PersistentConfig `
                -WorkingConfigPath $WorkingConfigPath -PersistentConfigPath $PersistentConfigPath
        }
    }
}

function Edit-PushCommands {
    param (
        [ref]$WorkingConfig,
        [ref]$PersistentConfig,
        [string]$WorkingConfigPath,
        [string]$PersistentConfigPath
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Edit Git Push Commands" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "`nCurrent push commands: " -NoNewline
    if ([string]::IsNullOrWhiteSpace($WorkingConfig.Value.repoSettings.repoPushCommands)) {
        Write-Host "(not set)" -ForegroundColor Gray
    } else {
        Write-Host $WorkingConfig.Value.repoSettings.repoPushCommands -ForegroundColor Yellow
    }
    
    Write-Host "`nEnter new git push commands:"
    Write-Host "  - Multiple commands can be separated by ';'" -ForegroundColor Gray
    Write-Host "  - Omit the 'git' part (e.g., use 'push origin main' not 'git push origin main')" -ForegroundColor Gray
    Write-Host "  - Press Enter without typing to keep current value" -ForegroundColor Gray
    Write-Host ""
    
    $newPushCommands = Read-Host "Push commands"
    
    # If response is empty, notify and keep existing value
    if ([string]::IsNullOrWhiteSpace($newPushCommands)) {
        Write-Host "`nConfiguration has not been changed." -ForegroundColor Yellow
        return
    }
    
    # Update the repoPushCommands in both configurations
    $WorkingConfig.Value.repoSettings.repoPushCommands = $newPushCommands
    $PersistentConfig.Value.repoSettings.repoPushCommands = $newPushCommands
    
    # Save to working config file
    try {
        $WorkingConfig.Value | ConvertTo-Json -Depth 10 | Set-Content -Path $WorkingConfigPath -Encoding UTF8
        Write-Host "`nUpdated: " -NoNewline
        Write-Host $WorkingConfigPath -ForegroundColor Green
    } catch {
        Write-Host "`nERROR: Failed to save working configuration" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return
    }
    
    # Save to persistent config file
    try {
        $PersistentConfig.Value | ConvertTo-Json -Depth 10 | Set-Content -Path $PersistentConfigPath -Encoding UTF8
        Write-Host "Updated: " -NoNewline
        Write-Host $PersistentConfigPath -ForegroundColor Green
    } catch {
        Write-Host "`nERROR: Failed to save persistent configuration" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return
    }
    
    Write-Host "`nPush commands successfully updated to: " -NoNewline
    Write-Host $newPushCommands -ForegroundColor Green
}

function Edit-NotebooksParameters {
    param (
        [ref]$WorkingConfig,
        [ref]$PersistentConfig,
        [string]$WorkingConfigPath,
        [string]$PersistentConfigPath
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Edit Notebooks Parameters" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    #region Edit Source Path
    
    Write-Host "`nCurrent notebooks source path: " -NoNewline
    if ([string]::IsNullOrWhiteSpace($WorkingConfig.Value.repoSettings.notebooks.sourcePath)) {
        Write-Host "(not set)" -ForegroundColor Gray
    } else {
        Write-Host $WorkingConfig.Value.repoSettings.notebooks.sourcePath -ForegroundColor Yellow
    }
    
    Write-Host "`nEnter new source path for notebooks (e.g., Colab notebooks on Google Drive):"
    Write-Host "  - Path should be absolute" -ForegroundColor Gray
    Write-Host "  - Press Enter without typing to keep current value" -ForegroundColor Gray
    Write-Host ""
    
    $newSourcePath = Read-Host "Source path"
    
    # If response is empty, notify and keep existing value
    if ([string]::IsNullOrWhiteSpace($newSourcePath)) {
        Write-Host "`nSource path configuration has not been changed." -ForegroundColor Yellow
    } else {
        # Validate that the path is absolute
        if (-not [System.IO.Path]::IsPathRooted($newSourcePath)) {
            Write-Host "`nERROR: Source path must be absolute (rooted)." -ForegroundColor Red
            Write-Host "Provided path: $newSourcePath" -ForegroundColor Red
            Write-Host "Notebooks parameters not updated. Returning to menu." -ForegroundColor Yellow
            return
        }
        
        # Validate that the path exists
        if (-not (Test-Path $newSourcePath)) {
            Write-Host "`nERROR: Source path does not exist: $newSourcePath" -ForegroundColor Red
            Write-Host "Please create the directory first, then run this configuration again." -ForegroundColor Yellow
            Write-Host "Notebooks parameters not updated. Returning to menu." -ForegroundColor Yellow
            return
        }
        
        # Update the source path in both configurations
        $WorkingConfig.Value.repoSettings.notebooks.sourcePath = $newSourcePath
        $PersistentConfig.Value.repoSettings.notebooks.sourcePath = $newSourcePath
        
        # Save to working config file
        try {
            $WorkingConfig.Value | ConvertTo-Json -Depth 10 | Set-Content -Path $WorkingConfigPath -Encoding UTF8
            Write-Host "`nUpdated: " -NoNewline
            Write-Host $WorkingConfigPath -ForegroundColor Green
        } catch {
            Write-Host "`nERROR: Failed to save working configuration" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            return
        }
        
        # Save to persistent config file
        try {
            $PersistentConfig.Value | ConvertTo-Json -Depth 10 | Set-Content -Path $PersistentConfigPath -Encoding UTF8
            Write-Host "Updated: " -NoNewline
            Write-Host $PersistentConfigPath -ForegroundColor Green
        } catch {
            Write-Host "`nERROR: Failed to save persistent configuration" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            return
        }
        
        Write-Host "`nSource path successfully updated to: " -NoNewline
        Write-Host $newSourcePath -ForegroundColor Green
    }
    
    #endregion
    
    #region Edit Destination Path
    
    Write-Host "`n----------------------------------------" -ForegroundColor Cyan
    Write-Host "`nCurrent notebooks destination path: " -NoNewline
    if ([string]::IsNullOrWhiteSpace($WorkingConfig.Value.repoSettings.notebooks.destinationPath)) {
        Write-Host "(not set)" -ForegroundColor Gray
    } else {
        Write-Host $WorkingConfig.Value.repoSettings.notebooks.destinationPath -ForegroundColor Yellow
    }
    
    Write-Host "`nEnter new destination path for notebooks:"
    Write-Host "  - Path can be absolute or relative to the working repository root" -ForegroundColor Gray
    Write-Host "  - Common value: 'notebooks'" -ForegroundColor Gray
    Write-Host "  - Press Enter without typing to keep current value" -ForegroundColor Gray
    Write-Host ""
    
    $newDestinationPath = Read-Host "Destination path"
    
    # If response is empty, notify and keep existing value
    if ([string]::IsNullOrWhiteSpace($newDestinationPath)) {
        Write-Host "`nDestination path configuration has not been changed." -ForegroundColor Yellow
        return
    }
    
    # Check whether the path is absolute (rooted)
    $absoluteDestinationPath = ""
    if ([System.IO.Path]::IsPathRooted($newDestinationPath)) {
        # Path is absolute, use as-is
        $absoluteDestinationPath = $newDestinationPath
        Write-Host "`nUsing absolute destination path: " -NoNewline
        Write-Host $absoluteDestinationPath -ForegroundColor Cyan
    } else {
        # Path is relative, resolve it relative to workingConfig.repoRoot
        $absoluteDestinationPath = Join-Path $WorkingConfig.Value.repoRoot $newDestinationPath
        Write-Host "`nResolving relative path to absolute:" -ForegroundColor Cyan
        Write-Host "  Working repo root: " -NoNewline
        Write-Host $WorkingConfig.Value.repoRoot -ForegroundColor Yellow
        Write-Host "  Relative path: " -NoNewline
        Write-Host $newDestinationPath -ForegroundColor Yellow
        Write-Host "  Absolute path: " -NoNewline
        Write-Host $absoluteDestinationPath -ForegroundColor Cyan
    }
    
    # Validate that the absolute destination path exists
    if (-not (Test-Path $absoluteDestinationPath)) {
        Write-Host "`nERROR: Destination path does not exist: $absoluteDestinationPath" -ForegroundColor Red
        Write-Host "Please create the directory first, then run this configuration again." -ForegroundColor Yellow
        Write-Host "Notebooks parameters not updated. Returning to menu." -ForegroundColor Yellow
        return
    }
    
    # Check that the absolute destination path is not equal to the source path
    $currentSourcePath = $WorkingConfig.Value.repoSettings.notebooks.sourcePath
    if (-not [string]::IsNullOrWhiteSpace($currentSourcePath)) {
        # Normalize paths for comparison (resolve to absolute, remove trailing slashes)
        $normalizedSource = [System.IO.Path]::GetFullPath($currentSourcePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        $normalizedDestination = [System.IO.Path]::GetFullPath($absoluteDestinationPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
        
        if ($normalizedSource -eq $normalizedDestination) {
            Write-Host "`nERROR: Destination path cannot be the same as source path." -ForegroundColor Red
            Write-Host "  Source: $normalizedSource" -ForegroundColor Red
            Write-Host "  Destination: $normalizedDestination" -ForegroundColor Red
            Write-Host "Notebooks parameters not updated. Returning to menu." -ForegroundColor Yellow
            return
        }
    }
    
    # Save the destination path value as entered by the user (not the absolute path)
    $WorkingConfig.Value.repoSettings.notebooks.destinationPath = $newDestinationPath
    $PersistentConfig.Value.repoSettings.notebooks.destinationPath = $newDestinationPath
    
    # Save to working config file
    try {
        $WorkingConfig.Value | ConvertTo-Json -Depth 10 | Set-Content -Path $WorkingConfigPath -Encoding UTF8
        Write-Host "`nUpdated: " -NoNewline
        Write-Host $WorkingConfigPath -ForegroundColor Green
    } catch {
        Write-Host "`nERROR: Failed to save working configuration" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return
    }
    
    # Save to persistent config file
    try {
        $PersistentConfig.Value | ConvertTo-Json -Depth 10 | Set-Content -Path $PersistentConfigPath -Encoding UTF8
        Write-Host "Updated: " -NoNewline
        Write-Host $PersistentConfigPath -ForegroundColor Green
    } catch {
        Write-Host "`nERROR: Failed to save persistent configuration" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return
    }
    
    Write-Host "`nDestination path successfully updated to: " -NoNewline
    Write-Host $newDestinationPath -ForegroundColor Green
    Write-Host "(Absolute path: " -NoNewline -ForegroundColor Gray
    Write-Host $absoluteDestinationPath -NoNewline -ForegroundColor Gray
    Write-Host ")" -ForegroundColor Gray
    
    #endregion
}

function Edit-InitCommands {
    param (
        [ref]$WorkingConfig,
        [ref]$PersistentConfig,
        [string]$WorkingConfigPath,
        [string]$PersistentConfigPath
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Edit Git Init Commands" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    Write-Host "`nCurrent init commands: " -NoNewline
    if ([string]::IsNullOrWhiteSpace($WorkingConfig.Value.repoSettings.initGitCommands)) {
        Write-Host "(not set)" -ForegroundColor Gray
    } else {
        Write-Host $WorkingConfig.Value.repoSettings.initGitCommands -ForegroundColor Yellow
    }
    
    Write-Host "`nEnter new git commands to initialize the repository:"
    Write-Host "  - Multiple commands can be separated by ';'" -ForegroundColor Gray
    Write-Host "  - Omit the 'git' part (e.g., use 'init' not 'git init')" -ForegroundColor Gray
    Write-Host "  - Press Enter without typing to keep current value" -ForegroundColor Gray
    Write-Host ""
    
    $newInitCommands = Read-Host "Init commands"
    
    # Track whether commands were changed
    $commandsChanged = $false
    
    # If response is empty, notify and keep existing value
    if ([string]::IsNullOrWhiteSpace($newInitCommands)) {
        Write-Host "`nConfiguration has not been changed." -ForegroundColor Yellow
        # Use existing commands for potential execution
        $commandsToRun = $WorkingConfig.Value.repoSettings.initGitCommands
    } else {
        # Update the initGitCommands in both configurations
        $WorkingConfig.Value.repoSettings.initGitCommands = $newInitCommands
        $PersistentConfig.Value.repoSettings.initGitCommands = $newInitCommands
        
        # Save to working config file
        try {
            $WorkingConfig.Value | ConvertTo-Json -Depth 10 | Set-Content -Path $WorkingConfigPath -Encoding UTF8
            Write-Host "`nUpdated: " -NoNewline
            Write-Host $WorkingConfigPath -ForegroundColor Green
        } catch {
            Write-Host "`nERROR: Failed to save working configuration" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            return
        }
        
        # Save to persistent config file
        try {
            $PersistentConfig.Value | ConvertTo-Json -Depth 10 | Set-Content -Path $PersistentConfigPath -Encoding UTF8
            Write-Host "Updated: " -NoNewline
            Write-Host $PersistentConfigPath -ForegroundColor Green
        } catch {
            Write-Host "`nERROR: Failed to save persistent configuration" -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            return
        }
        
        Write-Host "`nInit commands successfully updated to: " -NoNewline
        Write-Host $newInitCommands -ForegroundColor Green
        
        $commandsChanged = $true
        $commandsToRun = $newInitCommands
    }
    
    # Ask user to proceed to running commands (whether changed or not)
    if (-not [string]::IsNullOrWhiteSpace($commandsToRun)) {
        Write-Host ""
        $proceedToRun = Read-Host "Proceed to running these commands? (Y/N)"
        
        if ($proceedToRun -match "^[Yy]") {
            Run-GitCommands -GitRootPath $WorkingConfig.Value.repoRoot -GitCommands $commandsToRun
        } else {
            if ($commandsChanged) {
                Write-Host "`nInit commands saved but not executed." -ForegroundColor Yellow
            } else {
                Write-Host "`nCommands not executed." -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "`nNo init commands are configured. Please set init commands first." -ForegroundColor Yellow
    }
}

function Run-GitCommands {
    param (
        [string]$GitRootPath,
        [string]$GitCommands
    )
    
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Running Git Commands" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    # Remember the location of the script
    $scriptDir = Get-Location
    
    Write-Host "`nGit root path: " -NoNewline
    Write-Host $GitRootPath -ForegroundColor Yellow
    Write-Host "Commands to execute: " -NoNewline
    Write-Host $GitCommands -ForegroundColor Yellow
    Write-Host ""
    
    # Validate that the git root path exists
    if (-not (Test-Path $GitRootPath)) {
        Write-Host "ERROR: Git root path does not exist: $GitRootPath" -ForegroundColor Red
        return
    }
    
    try {
        # Set location to Git root path
        Set-Location -Path $GitRootPath
        Write-Host "Changed directory to: " -NoNewline
        Write-Host $GitRootPath -ForegroundColor Green
        
        # Split the Git commands string by ";"
        $commandArray = $GitCommands -split ';'
        
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
        
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Git Commands Execution Complete" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        
    } finally {
        # Set location back to script directory
        Set-Location -Path $scriptDir
        Write-Host "`nReturned to: " -NoNewline
        Write-Host $scriptDir -ForegroundColor Green
    }
}

#endregion

#region Main Script

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Config-WorkRepo - Working Repository Configuration Editor" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Define configuration file paths
$instanceConfigPath = Join-Path $PSScriptRoot "_Params-Instance-Repo.json"
$hostConfigPath = Join-Path $PSScriptRoot "_Params-Host-Repo.json"
$workingConfigPath = Join-Path $PSScriptRoot "_Params-Working-Repo.json"

# Step 1: Read instanceType from _Params-Instance-Repo.json
try {
    if (-not (Test-Path $instanceConfigPath)) {
        Write-Host "`nERROR: Instance configuration file not found: $instanceConfigPath" -ForegroundColor Red
        exit 1
    }
    
    $instanceConfig = Get-Content $instanceConfigPath -Raw | ConvertFrom-Json
    $instanceType = $instanceConfig.instanceType
    
    Write-Host "`nInstance Type: " -NoNewline
    Write-Host $instanceType -ForegroundColor Green
    
} catch {
    Write-Host "`nERROR: Failed to read or parse instance configuration file" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Step 2: Choose persistent config file according to instance type
if ($instanceType -eq "standalone") {
    $persistentConfigPath = $instanceConfigPath
    Write-Host "Persistent config: " -NoNewline
    Write-Host "_Params-Instance-Repo.json" -ForegroundColor Green
} elseif ($instanceType -eq "companion") {
    $persistentConfigPath = $hostConfigPath
    Write-Host "Persistent config: " -NoNewline
    Write-Host "_Params-Host-Repo.json" -ForegroundColor Green
} else {
    Write-Host "`nERROR: Invalid instance type: $instanceType" -ForegroundColor Red
    Write-Host "Expected 'standalone' or 'companion'" -ForegroundColor Red
    exit 1
}

# Step 3: Read parameters from working config
try {
    if (-not (Test-Path $workingConfigPath)) {
        Write-Host "`nERROR: Working configuration file not found: $workingConfigPath" -ForegroundColor Red
        Write-Host "Please run Assume-Attached.ps1 or Assume-Detached.ps1 first to initialize the working configuration." -ForegroundColor Yellow
        exit 1
    }
    
    $workingConfig = Get-Content $workingConfigPath -Raw | ConvertFrom-Json
    
} catch {
    Write-Host "`nERROR: Failed to read or parse working configuration file" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Step 4: Read persistent config
try {
    if (-not (Test-Path $persistentConfigPath)) {
        Write-Host "`nERROR: Persistent configuration file not found: $persistentConfigPath" -ForegroundColor Red
        exit 1
    }
    
    $persistentConfig = Get-Content $persistentConfigPath -Raw | ConvertFrom-Json
    
} catch {
    Write-Host "`nERROR: Failed to read or parse persistent configuration file" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}

# Step 5: Display current configuration
Show-CurrentConfiguration -InstanceType $instanceType -RepoRoot $workingConfig.repoRoot -RepoSettings $workingConfig.repoSettings

# Step 6: Interactive menu loop
$continue = $true
while ($continue) {
    Show-Menu
    
    $choice = Read-Host "Enter your choice"
    
    switch ($choice) {
        "1" {
            Edit-RepositoryType -WorkingConfig ([ref]$workingConfig) -PersistentConfig ([ref]$persistentConfig) `
                -WorkingConfigPath $workingConfigPath -PersistentConfigPath $persistentConfigPath
        }
        "2" {
            Edit-PushCommands -WorkingConfig ([ref]$workingConfig) -PersistentConfig ([ref]$persistentConfig) `
                -WorkingConfigPath $workingConfigPath -PersistentConfigPath $persistentConfigPath
        }
        "3" {
            Edit-NotebooksParameters -WorkingConfig ([ref]$workingConfig) -PersistentConfig ([ref]$persistentConfig) `
                -WorkingConfigPath $workingConfigPath -PersistentConfigPath $persistentConfigPath
        }
        "4" {
            Edit-InitCommands -WorkingConfig ([ref]$workingConfig) -PersistentConfig ([ref]$persistentConfig) `
                -WorkingConfigPath $workingConfigPath -PersistentConfigPath $persistentConfigPath
        }
        "0" {
            Write-Host "`nExiting configuration editor." -ForegroundColor Green
            $continue = $false
        }
        default {
            Write-Host "`nInvalid choice. Please select a valid option (0-4)." -ForegroundColor Yellow
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Configuration Editor Closed" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

#endregion