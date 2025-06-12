<#
.SYNOPSIS
    Downloads and runs the Ookla Speedtest CLI tool to perform internet speed tests with network information.

.DESCRIPTION
    This script automatically downloads the Ookla Speedtest CLI application, extracts it to a temporary location, 
    and executes a speed test. Additionally, it gathers comprehensive network information including DNS servers,
    default gateway, network adapters, and public IP details. The script ensures it runs with administrator 
    privileges and handles cleanup of temporary files after execution.

.PARAMETER None
    This script does not accept any parameters.

.EXAMPLE
    .\Speedtest_CLI.ps1
    Downloads the Speedtest CLI, runs a speed test, and displays network information.

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

# Function to get network information
function Get-NetworkInfo {
    Write-Host "`nGathering network information..." -ForegroundColor Cyan
    
    # Get active network adapter
    $activeAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" -and $_.InterfaceType -ne "Software Loopback" } | Select-Object -First 1
    
    # Get IP configuration
    $ipConfig = Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Name -eq $activeAdapter.Name }
    
    # Get DNS servers
    $dnsServers = Get-DnsClientServerAddress | Where-Object { $_.InterfaceAlias -eq $activeAdapter.Name -and $_.AddressFamily -eq 2 }
    
    # Get public IP from multiple sources for reliability
    $publicIp = $null
    $publicIpSources = @(
        "https://api.ipify.org",
        "https://icanhazip.com",
        "https://ipinfo.io/ip"
    )
    
    foreach ($source in $publicIpSources) {
        try {
            $publicIp = (Invoke-RestMethod -Uri $source -TimeoutSec 5).Trim()
            break
        }
        catch {
            continue
        }
    }
    
    return @{
        ActiveAdapter = $activeAdapter
        IPConfig = $ipConfig
        DNSServers = $dnsServers.ServerAddresses
        PublicIP = $publicIp
        DefaultGateway = $ipConfig.IPv4DefaultGateway.NextHop
        LocalIP = $ipConfig.IPv4Address.IPAddress
        SubnetMask = $ipConfig.IPv4Address.PrefixLength
    }
}

try {
    # Get network information first
    $networkInfo = Get-NetworkInfo
    
    Write-Host "Downloading Speedtest CLI..." -ForegroundColor Green
    Invoke-WebRequest -Uri $speedtestUrl -OutFile $zipFile -ErrorAction Stop
    
    Write-Host "Extracting files..." -ForegroundColor Green
    Expand-Archive -Path $zipFile -DestinationPath $tempPath -Force -ErrorAction Stop
    
    Write-Host "Running speed test..." -ForegroundColor Green
    Push-Location $tempPath
    $ResultsJson = & ".\speedtest.exe" --accept-license --accept-gdpr --format=json --accept-license
    Pop-Location
    
    Write-Host "Speed test completed!" -ForegroundColor Green

    clear-host

    $results = $ResultsJson | ConvertFrom-Json 
    $downloadSpeed = [math]::Round($Results.download.bandwidth * 8 / 1MB, 2)
    $uploadSpeed = [math]::Round($Results.upload.bandwidth * 8 / 1MB, 2)
    $pingLatency = [math]::Round($Results.ping.latency, 2)
    $jitter = [math]::Round($Results.ping.jitter, 2)
    $packetLoss = $Results.packetLoss
    
    # Get geolocation information
    $geoInfo = $null
    try {
        $geoInfo = Invoke-RestMethod -Uri "http://ip-api.com/json/$($networkInfo.PublicIP)" -TimeoutSec 10
    }
    catch {
        Write-Warning "Could not retrieve geolocation information"
    }

    # Create one comprehensive PSCustomObject
    $speedtestResults = [PSCustomObject]@{
        # Speed Test Results
        DownloadSpeed_Mbps = $downloadSpeed
        UploadSpeed_Mbps = $uploadSpeed
        PingLatency_ms = $pingLatency
        Jitter_ms = $jitter
        PacketLoss_Percent = $packetLoss
        ISP = $Results.isp
        TestServer = "$($Results.server.name) - $($Results.server.location), $($Results.server.country)"
        TestURL = $Results.result.url
        
        # Network Information
        ActiveAdapter = $networkInfo.ActiveAdapter.Name
        AdapterType = $networkInfo.ActiveAdapter.InterfaceDescription
        LinkSpeed = $networkInfo.ActiveAdapter.LinkSpeed
        MACAddress = $networkInfo.ActiveAdapter.MacAddress
        LocalIP = "$($networkInfo.LocalIP)/$($networkInfo.SubnetMask)"
        DefaultGateway = $networkInfo.DefaultGateway
        PublicIP = $networkInfo.PublicIP
        DNSServers = ($networkInfo.DNSServers -join ", ")
        ConnectionState = $networkInfo.ActiveAdapter.Status
        
        # Geolocation Information
        Country = if ($geoInfo -and $geoInfo.status -eq "success") { $geoInfo.country } else { "N/A" }
        Region = if ($geoInfo -and $geoInfo.status -eq "success") { $geoInfo.regionName } else { "N/A" }
        City = if ($geoInfo -and $geoInfo.status -eq "success") { $geoInfo.city } else { "N/A" }
        ZipCode = if ($geoInfo -and $geoInfo.status -eq "success") { $geoInfo.zip } else { "N/A" }
        Latitude = if ($geoInfo -and $geoInfo.status -eq "success") { $geoInfo.lat } else { "N/A" }
        Longitude = if ($geoInfo -and $geoInfo.status -eq "success") { $geoInfo.lon } else { "N/A" }
        Timezone = if ($geoInfo -and $geoInfo.status -eq "success") { $geoInfo.timezone } else { "N/A" }
        GeoISP = if ($geoInfo -and $geoInfo.status -eq "success") { $geoInfo.isp } else { "N/A" }
        ASNumber = if ($geoInfo -and $geoInfo.status -eq "success") { $geoInfo.as } else { "N/A" }
    }

    # Output the PSCustomObject
    return $speedtestResults

}
catch {
}
finally {
    # Cleanup - ensure we're not in the temp directory
    Set-Location $env:TEMP
    if (Test-Path $zipFile) { Remove-Item $zipFile -Force }
    if (Test-Path $tempPath) { Remove-Item $tempPath -Recurse -Force }
}

Read-Host "Press Enter to exit"
