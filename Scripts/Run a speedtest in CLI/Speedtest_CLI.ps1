<#
.SYNOPSIS
    Downloads and runs the Ookla Speedtest CLI tool to perform internet speed tests.

.DESCRIPTION
    This script automatically downloads the Ookla Speedtest CLI application, extracts it to a temporary location, 
    and executes a speed test. The script ensures it runs with administrator privileges and handles cleanup of 
    temporary files after execution. If not running as administrator, it will restart itself with elevated permissions.

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    .\Speedtest in CLI.ps1
    Downloads the Speedtest CLI and runs a speed test with automatic license acceptance.

.NOTES
    Author: Roy Klooster
    Requires: Administrator privileges
    Dependencies: Internet connection to download Speedtest CLI
    Cleanup: Automatically removes downloaded files and temporary directories

#>
[CmdletBinding()]
param()

# Check if running as administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "This script requires administrator privileges." -ForegroundColor Yellow

    Read-Host "Press Enter to exit"
    exit 
}

# Configuration
$speedtestUrl = "https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-win64.zip"
$tempPath = Join-Path $env:TEMP "speedtest"
$zipFile = Join-Path $env:TEMP "speedtest.zip"

try {
    Write-Host "Downloading Speedtest CLI..." -ForegroundColor Green
    Invoke-WebRequest -Uri $speedtestUrl -OutFile $zipFile -ErrorAction Stop
    
    Write-Host "Extracting files..." -ForegroundColor Green
    Expand-Archive -Path $zipFile -DestinationPath $tempPath -Force -ErrorAction Stop
    
    Write-Host "Running speed test..." -ForegroundColor Green
    Push-Location $tempPath
    & ".\speedtest.exe" --accept-license --accept-gdpr
    
    Write-Host "Speed test completed!" -ForegroundColor Green
}
catch {
    Write-Error "Error occurred: $($_.Exception.Message)"
}
finally {
    # Cleanup
    Pop-Location
    if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
    if (Test-Path $tempPath) { Remove-Item $tempPath -Recurse -Force }
}

Read-Host "Press Enter to exit"
