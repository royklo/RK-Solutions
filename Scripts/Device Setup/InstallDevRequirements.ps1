<#
.SYNOPSIS
    Complete Development Environment Setup Script for New Devices (PowerShell 5.1+ Compatible)
.DESCRIPTION
    This script sets up a complete PowerShell environment including:
    - Applications via winget
    - PowerShell modules with update checking
    - VS Code extensions
    - PowerShell profiles with custom functions
.NOTES
    Author: Roy Klooster - RKSolutions
    Version: 1.2 (PowerShell 5.1 Compatible - Enhanced Module Management)
    Requires: Windows with winget, Administrator privileges, PowerShell 5.1 or later
    Tested on: Windows 10/11, PowerShell 5.1, PowerShell 7.x
    Date: 2025-06-23
#>

# ============================================================================
# CONFIGURATION SECTION - MODIFY THESE ARRAYS AS NEEDED
# ============================================================================

# Applications to install via winget
$installApps = @{
    "Git.Git"                        = "Git"
    "Microsoft.PowerShell"           = "PowerShell 7"
    "Microsoft.VisualStudioCode"     = "VS Code"
}

# PowerShell modules to install
$RequiredModules = @(
    "Az",
    "ExchangeOnlineManagement",
    "M365Permissions",
    "Microsoft.Graph",
    "Microsoft.Graph.Entra",
    "Microsoft.graph.beta",
    "PNP.Powershell",
    "Wintuner",
    "ZeroTrustAssessment"
)

# VS Code extensions to install
$VSCodeExtensions = @(
    "github.copilot",                       # GitHub Copilot
    "ms-vsliveshare.vsliveshare",           # Live Share
    "ms-vscode.powershell",                 # PowerShell Extension
    "gruntfuggly.todo-tree",                # TODO Tree
    "mechatroner.rainbow-csv",              # Rainbow CSV
    "azemoh.one-monokai",                   # One Monokai Theme
    "ms-azuretools.vscode-bicep",           # Bicep Extension
    "microsoft-dciborow.align-bicep",       # Align Bicep
    "eamodio.gitlens",                      # GitLens
    "shd101wyy.markdown-preview-enhanced"   # Markdown Preview Enhanced
)

# ============================================================================
# MAIN SCRIPT
# ============================================================================

Clear-Host

# Progress tracking variables
$totalSteps = 5
$currentStep = 0

function Write-Progress-Step {
    param([string]$Activity, [string]$Status)
    $script:currentStep++
    Write-Progress -Activity $Activity -Status $Status -PercentComplete (($script:currentStep / $totalSteps) * 100)
}

# PowerShell 5.1 compatible platform detection
function Test-IsWindows {
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        # PowerShell Core/7+ has $IsWindows variable
        return $IsWindows
    } else {
        # PowerShell 5.1 and earlier are Windows-only
        return $true
    }
}

function Get-PlatformType {
    if (Test-Path "C:\Mac") {
        return "ParallelsVM"
    } elseif (Test-IsWindows) {
        return "Windows"
    } else {
        return "Unix"
    }
}

Write-Host "=== PowerShell Environment Setup ===" -ForegroundColor Magenta
Write-Host "Setting up your new device with all the essentials..." -ForegroundColor Cyan
Write-Host ""

# Step 1: Check dependencies and upgrades
Write-Progress-Step "Checking Dependencies" "Verifying winget installation and checking for upgrades"
Write-Host "Checking Dependencies..." -ForegroundColor Cyan

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget not found. Please install App Installer from Microsoft Store." -ForegroundColor Red
    exit 1
}
Write-Host "* winget is available" -ForegroundColor Green

# Check for winget upgrades
Write-Host "Checking for available upgrades for target applications..." -ForegroundColor Cyan
foreach ($app in $installApps.GetEnumerator()) {
    $appId = $app.Key
    $friendlyName = $app.Value
    
    Write-Host "  Checking $friendlyName for upgrades..." -ForegroundColor Yellow -NoNewline
    try {
        $upgradeResult = & winget upgrade $appId --accept-source-agreements 2>&1
        $upgradeOutput = $upgradeResult -join "`n"
        
        if ($upgradeOutput -match "No installed package found") {
            Write-Host " Not installed" -ForegroundColor Gray
        } elseif ($upgradeOutput -match "No available upgrade found" -or $upgradeOutput -match "is already installed") {
            Write-Host " Up to date" -ForegroundColor Green
        } elseif ($upgradeOutput -match "Successfully installed") {
            Write-Host " Upgraded successfully" -ForegroundColor Green
        } else {
            Write-Host " Installing/Upgrading..." -ForegroundColor Cyan
            $upgradeProcess = Start-Process -FilePath "winget" -ArgumentList "upgrade $appId --silent --accept-package-agreements --accept-source-agreements" -Wait -NoNewWindow -PassThru
            if ($upgradeProcess.ExitCode -eq 0) {
                Write-Host "    * $friendlyName upgraded" -ForegroundColor Green
            } else {
                Write-Host "    * No upgrade needed or already current" -ForegroundColor Green
            }
        }
    } catch {
        Write-Host " Could not check upgrade status" -ForegroundColor Yellow
    }
}
Write-Host ""

# Step 2: Install applications
Write-Progress-Step "Installing Applications" "Installing winget packages"
Write-Host "Installing Applications..." -ForegroundColor Cyan

$appCount = 0
$totalApps = $installApps.Count

foreach ($app in $installApps.GetEnumerator()) {
    $appCount++
    $friendlyName = $app.Value
    $appId = $app.Key
    
    Write-Host "[$appCount/$totalApps] Installing $friendlyName..." -ForegroundColor Yellow -NoNewline
    try {
        # First check if already installed
        $listResult = & winget list $appId 2>&1
        $listOutput = $listResult -join "`n"
        
        if ($listOutput -match $appId -and $listOutput -notmatch "No installed package found") {
            Write-Host " Already installed" -ForegroundColor Green
            continue
        }
        
        $process = Start-Process -FilePath "winget" -ArgumentList "install $appId --silent --accept-package-agreements --accept-source-agreements -e" -Wait -NoNewWindow -PassThru -ErrorAction Stop
        
        # Handle common winget exit codes
        switch ($process.ExitCode) {
            0 { 
                Write-Host " * Success" -ForegroundColor Green 
            }
            -1978335189 { 
                Write-Host " Already installed" -ForegroundColor Green 
            }
            -1978335212 { 
                Write-Host " Already installed (newer version)" -ForegroundColor Green 
            }
            default { 
                Write-Host " x Failed (Exit Code: $($process.ExitCode))" -ForegroundColor Red 
            }
        }
    } catch {
        Write-Host " x Failed: $_" -ForegroundColor Red
    }
}
Write-Host ""

# Step 3: Install PowerShell modules with enhanced checking
Write-Progress-Step "Installing Modules" "Installing PowerShell modules with update checking"
Write-Host "Installing PowerShell Modules..." -ForegroundColor Cyan

if ($RequiredModules.Count -gt 0) {
    # Performance optimization: Fetch all module information once before the loop
    Write-Host "Gathering module information for performance optimization..." -ForegroundColor Yellow
    
    # Get all installed modules with version information
    $installedModulesHash = @{}
    try {
        Write-Host "  Fetching installed modules..." -ForegroundColor Gray
        $installedModules = Get-Module -ListAvailable | Group-Object Name | ForEach-Object {
            # Get the latest version for each module
            $latestVersion = $_.Group | Sort-Object Version -Descending | Select-Object -First 1
            @{
                Name = $_.Name
                Version = $latestVersion.Version
                Module = $latestVersion
            }
        }
        
        foreach ($module in $installedModules) {
            $installedModulesHash[$module.Name] = $module
        }
        
        Write-Host "  Found $($installedModulesHash.Count) installed modules" -ForegroundColor Green
    } catch {
        Write-Host "  Warning: Could not retrieve installed modules list: $($_.Exception.Message)" -ForegroundColor Yellow
        $installedModulesHash = @{}
    }
    
    # Get available modules from PowerShell Gallery for update checking
    $galleryModulesHash = @{}
    try {
        Write-Host "  Fetching PowerShell Gallery information..." -ForegroundColor Gray
        
        # Use Find-Module to get latest versions from gallery (batch operation for better performance)
        $galleryModules = Find-Module -Name $RequiredModules -ErrorAction SilentlyContinue
        
        foreach ($module in $galleryModules) {
            $galleryModulesHash[$module.Name] = @{
                Name = $module.Name
                Version = $module.Version
                Module = $module
            }
        }
        
        Write-Host "  Found $($galleryModulesHash.Count) modules in PowerShell Gallery" -ForegroundColor Green
    } catch {
        Write-Host "  Warning: Could not retrieve PowerShell Gallery information: $($_.Exception.Message)" -ForegroundColor Yellow
        $galleryModulesHash = @{}
    }
    
    Write-Host ""
    
    $moduleCount = 0
    $totalModules = $RequiredModules.Count
    $modulesToInstall = @()
    $modulesToUpdate = @()
    $modulesUpToDate = @()

    # Analyze modules first
    Write-Host "Analyzing module requirements..." -ForegroundColor Cyan
    foreach ($moduleName in $RequiredModules) {
        $moduleCount++
        Write-Host "[$moduleCount/$totalModules] Analyzing $moduleName..." -ForegroundColor Yellow -NoNewline

        $installedModule = $installedModulesHash[$moduleName]
        $galleryModule = $galleryModulesHash[$moduleName]

        if (-not $installedModule) {
            # Module not installed
            Write-Host " Not installed" -ForegroundColor Red
            $modulesToInstall += @{
                Name = $moduleName
                Action = "Install"
                GalleryVersion = if ($galleryModule) { $galleryModule.Version } else { "Unknown" }
            }
        } elseif ($galleryModule -and ($installedModule.Version -lt $galleryModule.Version)) {
            # Module needs update
            Write-Host " Update available ($($installedModule.Version) -> $($galleryModule.Version))" -ForegroundColor Yellow
            $modulesToUpdate += @{
                Name = $moduleName
                Action = "Update"
                CurrentVersion = $installedModule.Version
                GalleryVersion = $galleryModule.Version
            }
        } else {
            # Module is up to date
            $currentVer = if ($installedModule) { $installedModule.Version } else { "Unknown" }
            Write-Host " Up to date ($currentVer)" -ForegroundColor Green
            $modulesUpToDate += @{
                Name = $moduleName
                Version = $currentVer
            }
        }
    }
    
    Write-Host ""
    Write-Host "Module Analysis Summary:" -ForegroundColor Cyan
    Write-Host "  To Install: $($modulesToInstall.Count)" -ForegroundColor Red
    Write-Host "  To Update: $($modulesToUpdate.Count)" -ForegroundColor Yellow  
    Write-Host "  Up to Date: $($modulesUpToDate.Count)" -ForegroundColor Green
    Write-Host ""

    # Install missing modules
    if ($modulesToInstall.Count -gt 0) {
        Write-Host "Installing missing modules..." -ForegroundColor Cyan
        $installCount = 0
        foreach ($moduleInfo in $modulesToInstall) {
            $installCount++
            $moduleName = $moduleInfo.Name
            Write-Host "[$installCount/$($modulesToInstall.Count)] Installing $moduleName..." -ForegroundColor Yellow -NoNewline
            
            try {
                Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
                Write-Host " * Success" -ForegroundColor Green
            } catch {
                Write-Host " x Failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
    
    # Update existing modules
    if ($modulesToUpdate.Count -gt 0) {
        Write-Host "Updating existing modules..." -ForegroundColor Cyan
        $updateCount = 0
        foreach ($moduleInfo in $modulesToUpdate) {
            $updateCount++
            $moduleName = $moduleInfo.Name
            Write-Host "[$updateCount/$($modulesToUpdate.Count)] Updating $moduleName ($($moduleInfo.CurrentVersion) -> $($moduleInfo.GalleryVersion))..." -ForegroundColor Yellow -NoNewline
            
            try {
                Update-Module -Name $moduleName -Force -ErrorAction Stop
                Write-Host " * Success" -ForegroundColor Green
            } catch {
                # If Update-Module fails, try Install-Module with -Force
                try {
                    Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
                    Write-Host " * Success (via reinstall)" -ForegroundColor Green
                } catch {
                    Write-Host " x Failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
        Write-Host ""
    }
    
    # Display up-to-date modules
    if ($modulesUpToDate.Count -gt 0) {
        Write-Host "Modules already up to date:" -ForegroundColor Green
        foreach ($moduleInfo in $modulesUpToDate) {
            Write-Host "  * $($moduleInfo.Name) ($($moduleInfo.Version))" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
} else {
    Write-Host "No PowerShell modules configured for installation." -ForegroundColor Gray
}
Write-Host ""

# Step 4: Install VS Code extensions
Write-Progress-Step "Installing Extensions" "Installing VS Code extensions"
Write-Host "Installing VS Code Extensions..." -ForegroundColor Cyan

# Refresh PATH to include newly installed applications
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

# Check for VS Code CLI with common installation paths
$codeCommand = $null
$codePaths = @(
    "code",
    "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd",
    "${env:ProgramFiles}\Microsoft VS Code\bin\code.cmd",
    "${env:ProgramFiles(x86)}\Microsoft VS Code\bin\code.cmd"
)

foreach ($path in $codePaths) {
    if (Get-Command $path -ErrorAction SilentlyContinue) {
        $codeCommand = $path
        break
    }
}

if (-not $codeCommand) {
    Write-Host "VS Code CLI (code) not found. Skipping extension installation." -ForegroundColor Yellow
    Write-Host "Please restart your terminal or add VS Code to PATH manually." -ForegroundColor Yellow
} else {
    Write-Host "VS Code CLI found at: $codeCommand" -ForegroundColor Green
    try {
        $installed = & $codeCommand --list-extensions 2>$null
        if (-not $installed) { $installed = @() }
        
        $extCount = 0
        $totalExts = $VSCodeExtensions.Count

        foreach ($ext in $VSCodeExtensions) {
            $extCount++
            Write-Host "[$extCount/$totalExts] Checking $ext..." -ForegroundColor Yellow -NoNewline
            
            if ($installed -contains $ext) {
                Write-Host " Already installed" -ForegroundColor Green
            } else {
                Write-Host " Installing..." -ForegroundColor Cyan
                try {
                    & $codeCommand --install-extension $ext --force 2>$null
                    Write-Host "    * $ext installed" -ForegroundColor Green
                } catch {
                    Write-Host "    x Failed to install $ext" -ForegroundColor Red
                }
            }
        }
    } catch {
        Write-Host "Error working with VS Code extensions: $($_.Exception.Message)" -ForegroundColor Red
    }
}
Write-Host ""

# Step 5: Set up PowerShell profiles
Write-Progress-Step "Setting Up PowerShell Profiles" "Configuring PowerShell profiles"
Write-Host "Setting Up PowerShell Profiles..." -ForegroundColor Cyan

# Set execution policy to allow script execution
Write-Host "Setting PowerShell execution policy..." -ForegroundColor Yellow
try {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Write-Host "Execution policy set to RemoteSigned for CurrentUser" -ForegroundColor Green
} catch {
    Write-Host "Failed to set execution policy: $($_.Exception.Message)" -ForegroundColor Red
}

# Functions to add to all profiles - PowerShell 5.1 compatible
$profileFunctions = @'
Function Get-PublicIP {
    (Invoke-WebRequest http://ifconfig.me/ip).Content
}

Function Get-UTCTime {
    (Get-Date).ToUniversalTime()
}

Function Find-TenantID {
    param(
        [Parameter(Position=0,mandatory=$true)]
        [string] $domain
    )
    try {
        $response = Invoke-RestMethod -UseBasicParsing -Uri "https://odc.officeapps.live.com/odc/v2.1/federationprovider?domain=$domain"
    }
    Catch {
        Return "Unable to run request"
    }
    $response.tenantid
}

function Get-RandomPassword {
    param (
        [Parameter(Mandatory=$true)]
        [int]$length
    )
    $characters = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890!@#$%^&*()'
    $password = for ($i = 0; $i -lt $length; $i++) {
        Get-Random -InputObject $characters.ToCharArray()
    }
    -join $password
}

# PSReadLine settings - PowerShell 5.1 compatible
try {
    if (-not (Get-Module -Name PSReadLine -ListAvailable)) {
        Write-Host "Installing PSReadLine module..." -ForegroundColor Yellow
        Install-Module PSReadLine -Force -Scope CurrentUser -AllowClobber -SkipPublisherCheck
    }
    
    Import-Module PSReadLine -Force
    
    # PowerShell 5.1 compatible PSReadLine options
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        Set-PSReadLineOption -HistorySearchCaseSensitive:$false -HistorySearchCursorMovesToEnd:$true -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView -HistoryNoDuplicates:$true -HistorySaveStyle SaveIncrementally -ShowToolTips:$true
    } elseif ($PSVersionTable.PSVersion.Major -eq 5) {
        # PowerShell 5.1 compatible options only
        Set-PSReadLineOption -HistorySearchCaseSensitive:$false -HistorySearchCursorMovesToEnd:$true -HistoryNoDuplicates:$true -HistorySaveStyle SaveIncrementally
        # ShowToolTips may not be available in older PSReadLine versions
        try {
            Set-PSReadLineOption -ShowToolTips:$true
        } catch {
            # Ignore if ShowToolTips is not supported
        }
    }
} catch {
    Write-Host "Warning: Could not configure PSReadLine: $($_.Exception.Message)" -ForegroundColor Yellow
}

function prompt {
    $time = Get-Date -Format "HH:mm:ss"
    Write-Host "[$time] " -NoNewline -ForegroundColor Cyan
    "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) "
}
'@

# Determine profile paths based on platform - PowerShell 5.1 compatible
$profilePaths = @()
$platformType = Get-PlatformType

switch ($platformType) {
    "ParallelsVM" {
        Write-Host "Detected Parallels Windows VM on Mac" -ForegroundColor Green
        
        # Parallels VM paths use C:\Mac\Home instead of standard Windows paths
        $parallelsUserProfile = "C:\Mac\Home"
        
        # Windows PowerShell 5.1 profile
        $winPSProfile = "$parallelsUserProfile\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        $profilePaths += $winPSProfile
        
        # PowerShell 7+ profile
        $ps7Profile = "$parallelsUserProfile\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        $profilePaths += $ps7Profile
        
        # VS Code profile (check both possible locations)
        $vscodeProfile1 = "$parallelsUserProfile\AppData\Roaming\Code\User\profile.ps1"
        $vscodeProfile2 = "C:\Mac\Home\Library\Application Support\Code\User\profile.ps1"
        
        if (Test-Path (Split-Path $vscodeProfile1 -Parent) -ErrorAction SilentlyContinue) {
            $profilePaths += $vscodeProfile1
        } elseif (Test-Path (Split-Path $vscodeProfile2 -Parent) -ErrorAction SilentlyContinue) {
            $profilePaths += $vscodeProfile2
        }
    }
    "Windows" {
        Write-Host "Detected Windows platform" -ForegroundColor Green
        
        # Windows PowerShell 5.1 profile
        $winPSProfile = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        $profilePaths += $winPSProfile
        
        # PowerShell 7+ profile
        $ps7Profile = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        $profilePaths += $ps7Profile
        
        # VS Code profile (if exists)
        if (Test-Path "$env:APPDATA\Code" -ErrorAction SilentlyContinue) {
            $vscodeProfile = "$env:APPDATA\Code\User\profile.ps1"
            $profilePaths += $vscodeProfile
        }
    }
    "Unix" {
        Write-Host "Detected Unix-like platform (macOS/Linux)" -ForegroundColor Green
        
        # PowerShell 7+ profile on Unix
        $unixProfile = "$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"
        $profilePaths += $unixProfile
        
        # VS Code profile on Unix (if exists)
        if (Test-Path "$HOME/.vscode" -ErrorAction SilentlyContinue) {
            $vscodeUnixProfile = "$HOME/.vscode/profile.ps1"
            $profilePaths += $vscodeUnixProfile
        }
    }
    default {
        Write-Host "Using default Windows platform detection" -ForegroundColor Green
        
        # Default to Windows paths
        $winPSProfile = "$env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        $profilePaths += $winPSProfile
        
        $ps7Profile = "$env:USERPROFILE\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"
        $profilePaths += $ps7Profile
        
        if (Test-Path "$env:APPDATA\Code" -ErrorAction SilentlyContinue) {
            $vscodeProfile = "$env:APPDATA\Code\User\profile.ps1"
            $profilePaths += $vscodeProfile
        }
    }
}

Write-Host "Profile paths to configure:" -ForegroundColor Cyan
$profilePaths | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

$profileCount = 0
$totalProfiles = $profilePaths.Count

foreach ($profilePath in $profilePaths) {
    $profileCount++
    try {
        $dir = Split-Path $profilePath -Parent
        
        # Create directory if it doesn't exist
        if (-not (Test-Path $dir)) { 
            Write-Host "[$profileCount/$totalProfiles] Creating directory: $dir" -ForegroundColor Yellow
            New-Item -Path $dir -ItemType Directory -Force -ErrorAction Stop | Out-Null
            
            # Verify directory was created
            if (-not (Test-Path $dir)) {
                Write-Host "Failed to create directory: $dir" -ForegroundColor Red
                continue
            }
        }
        
        # Check if profile already exists
        if (Test-Path $profilePath) {
            Write-Host "[$profileCount/$totalProfiles] Backing up existing profile: $profilePath" -ForegroundColor Yellow
            $backupPath = "$profilePath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Copy-Item -Path $profilePath -Destination $backupPath -Force
            Write-Host "    Backup created: $backupPath" -ForegroundColor Green
        }
        
        # Create the profile
        Write-Host "[$profileCount/$totalProfiles] Creating profile: $profilePath" -ForegroundColor Yellow
        Set-Content -Path $profilePath -Value $profileFunctions -Force -Encoding UTF8 -ErrorAction Stop
        
        # Verify profile was created and has content
        if ((Test-Path $profilePath) -and ((Get-Content $profilePath -Raw).Length -gt 0)) {
            Write-Host "    Profile configured successfully" -ForegroundColor Green
        } else {
            Write-Host "    Profile creation failed or file is empty" -ForegroundColor Red
        }
        
        # Test if the profile can be dot-sourced (syntax check)
        try {
            $null = [scriptblock]::Create((Get-Content $profilePath -Raw))
            Write-Host "    Profile syntax validated" -ForegroundColor Green
        } catch {
            Write-Host "    Profile syntax error: $($_.Exception.Message)" -ForegroundColor Red
        }
        
    } catch {
        Write-Host "[$profileCount/$totalProfiles] Error processing profile $profilePath : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""

# Display final summary
Write-Host "=== Setup Complete! ===" -ForegroundColor Magenta
Write-Host ""

Write-Host "Applications installed:" -ForegroundColor Cyan
$installApps.GetEnumerator() | ForEach-Object { Write-Host "  * $($_.Value)" -ForegroundColor Green }

Write-Host ""
Write-Host "PowerShell modules:" -ForegroundColor Cyan
if ($modulesToInstall.Count -gt 0 -or $modulesToUpdate.Count -gt 0) {
    Write-Host "  * $($modulesToInstall.Count) modules installed" -ForegroundColor Green
    Write-Host "  * $($modulesToUpdate.Count) modules updated" -ForegroundColor Yellow
}
Write-Host "  * $($modulesUpToDate.Count) modules already up to date" -ForegroundColor Green
Write-Host "  * Total: $($RequiredModules.Count) modules processed" -ForegroundColor Cyan

Write-Host ""
Write-Host "VS Code extensions:" -ForegroundColor Cyan
Write-Host "  * $($VSCodeExtensions.Count) extensions processed" -ForegroundColor Green

Write-Host ""
Write-Host "PowerShell profiles:" -ForegroundColor Cyan
foreach ($profilePath in $profilePaths) {
    if (Test-Path $profilePath) {
        $size = (Get-Item $profilePath).Length
        Write-Host "  * $profilePath ($size bytes)" -ForegroundColor Green
    } else {
        Write-Host "  x $profilePath (not created)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Setup complete! Please restart PowerShell or run '. `$PROFILE' to load your new profile." -ForegroundColor Green
Write-Host "Your development environment is ready to go!" -ForegroundColor Cyan

Write-Progress -Activity "Complete" -Completed