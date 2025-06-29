function Get-AllUsersMappedDrives {
    <#
    .SYNOPSIS
        Gets mapped network drives for all users on the system.
    
    .DESCRIPTION
        This function checks the registry for mapped network drives for all user profiles on the system.
        Requires administrator privileges to access other users' registry hives.
    
    .PARAMETER IncludeDisconnected
        Include drives that may be disconnected or inaccessible
    
    .PARAMETER UserName
        Filter results to a specific username (optional)
    
    .PARAMETER ReturnObject
        Return results as PowerShell objects instead of displaying to console
    
    .EXAMPLE
        Get-AllUsersMappedDrives
        
    .EXAMPLE
        Get-AllUsersMappedDrives -UserName "john.doe" -ReturnObject
        
    .EXAMPLE
        $drives = Get-AllUsersMappedDrives -ReturnObject
    
    .NOTES
        Requires administrator privileges to access other users' registry data.
    #>
    
    [CmdletBinding()]
    param(
        [switch]$IncludeDisconnected,
        [string]$UserName,
        [switch]$ReturnObject
    )
    
    begin {
        # Check if running as administrator
        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Warning "This function requires administrator privileges to access other users' registry data."
        }
        
        $results = @()
        $totalDrivesFound = 0
    }
    
    process {
        Write-Verbose "Starting to enumerate user profiles..."
        
        try {
            # Get all user profiles
            $users = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" | 
                Where-Object { $_.GetValue("ProfileImagePath") -like "*\Users\*" }
            
            Write-Verbose "Found $($users.Count) user profiles to check."
            
            if ($users.Count -eq 0) {
                Write-Host "No user profiles found in registry." -ForegroundColor Red
                return
            }
            
            $usersProcessed = 0
            $usersWithDrives = 0
            
            foreach ($user in $users) {
                $usersProcessed++
                $sid = $user.PSChildName
                $profilePath = $user.GetValue("ProfileImagePath")
                $currentUserName = Split-Path $profilePath -Leaf
                
                Write-Verbose "Processing user $usersProcessed/$($users.Count): $currentUserName (SID: $sid)"
                
                # Skip if filtering by username and this doesn't match
                if ($UserName -and $currentUserName -ne $UserName) {
                    Write-Verbose "Skipping user $currentUserName (doesn't match filter: $UserName)"
                    continue
                }
                
                try {
                    $userNetworkPath = "Registry::HKEY_USERS\$sid\Network"
                    
                    Write-Verbose "Checking registry path: $userNetworkPath"
                    
                    if (Test-Path $userNetworkPath) {
                        $mappedDrives = Get-ChildItem $userNetworkPath -ErrorAction SilentlyContinue
                        
                        Write-Verbose "Found $($mappedDrives.Count) potential drive mappings for $currentUserName"
                        
                        if ($mappedDrives) {
                            $usersWithDrives++
                            if (-not $ReturnObject) {
                                Write-Host "User: $currentUserName" -ForegroundColor Cyan
                            }
                            
                            foreach ($drive in $mappedDrives) {
                                try {
                                    $driveProperties = Get-ItemProperty $drive.PSPath -ErrorAction SilentlyContinue
                                    $driveLetter = $drive.PSChildName
                                    $remotePath = $driveProperties.RemotePath
                                    $providerName = $driveProperties.ProviderName
                                    $connectionType = $driveProperties.ConnectionType
                                    $userName = $driveProperties.UserName
                                    
                                    Write-Verbose "Successfully read drive $driveLetter -> $remotePath"
                                    $totalDrivesFound++
                                    
                                    if ($ReturnObject) {
                                        $driveInfo = [PSCustomObject]@{
                                            UserName = $currentUserName
                                            SID = $sid
                                            DriveLetter = $driveLetter
                                            RemotePath = $remotePath
                                            ProviderName = $providerName
                                            ConnectionType = $connectionType
                                            MappedUserName = $userName
                                            ProfilePath = $profilePath
                                        }
                                        $results += $driveInfo
                                    } else {
                                        Write-Host "  Drive $($driveLetter): -> $remotePath" -ForegroundColor Yellow
                                        if ($providerName) {
                                            Write-Host "    Provider: $providerName" -ForegroundColor Gray
                                        }
                                        if ($userName) {
                                            Write-Host "    Mapped User: $userName" -ForegroundColor Gray
                                        }
                                    }
                                }
                                catch {
                                    Write-Verbose "Failed to read properties for drive $($drive.PSChildName): $($_.Exception.Message)"
                                    if ($IncludeDisconnected) {
                                        $totalDrivesFound++
                                        if ($ReturnObject) {
                                            $driveInfo = [PSCustomObject]@{
                                                UserName = $currentUserName
                                                SID = $sid
                                                DriveLetter = $drive.PSChildName
                                                RemotePath = "Unable to read"
                                                ProviderName = $null
                                                ConnectionType = $null
                                                MappedUserName = $null
                                                ProfilePath = $profilePath
                                            }
                                            $results += $driveInfo
                                        } else {
                                            Write-Host "  Drive $($drive.PSChildName): -> Unable to read drive properties" -ForegroundColor Red
                                        }
                                    }
                                }
                            }
                        } else {
                            Write-Verbose "User $currentUserName has Network registry key but no mapped drives"
                        }
                    } else {
                        Write-Verbose "No Network registry path found for user $currentUserName"
                    }
                }
                catch {
                    Write-Verbose "Unable to access registry for user: $currentUserName (SID: $sid) - Error: $($_.Exception.Message)"
                    if (-not $ReturnObject) {
                        Write-Host "Unable to access registry for user: $currentUserName" -ForegroundColor Red
                    }
                }
            }
            
            Write-Verbose "Processed $usersProcessed users, $usersWithDrives had mapped drives"
            
        }
        catch {
            Write-Error "Failed to enumerate user profiles: $($_.Exception.Message)"
            Write-Host "Critical error occurred while enumerating user profiles." -ForegroundColor Red
            Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    end {
        Write-Verbose "Function completed. Found $totalDrivesFound mapped drives total."
        
        if ($ReturnObject) {
            if ($results.Count -eq 0) {
                Write-Verbose "No results found, returning empty array."
            }
            return $results
        } else {
            # Always provide feedback when not returning objects
            if ($totalDrivesFound -eq 0) {
                Write-Host "No mapped network drives found for any users." -ForegroundColor Yellow
                Write-Host "This could mean:" -ForegroundColor Gray
                Write-Host "  - No users have mapped drives" -ForegroundColor Gray
                Write-Host "  - Registry access is restricted" -ForegroundColor Gray
                Write-Host "  - User profiles couldn't be enumerated" -ForegroundColor Gray
            } else {
                Write-Host "`nScan completed. Found $totalDrivesFound mapped drive(s) total." -ForegroundColor Green
            }
        }
    }
}

# Example usage:
# Get-AllUsersMappedDrives
# Get-AllUsersMappedDrives -UserName "john.doe"
# $drives = Get-AllUsersMappedDrives -ReturnObject
# Get-AllUsersMappedDrives -ReturnObject | Format-Table -AutoSize