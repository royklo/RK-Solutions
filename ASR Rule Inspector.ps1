function Test-AdminElevation {
    # Check for elevated permissions
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}


Function Get-ASRStatus {
    $check = Test-AdminElevation

    $asrrules = @(
        [PSCustomObject]@{ Name = "Block executable content from email client and webmail"; GUID = "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550" },
        [PSCustomObject]@{ Name = "Block all Office applications from creating child processes"; GUID = "D4F940AB-401B-4EFC-AADC-AD5F3C50688A" },
        [PSCustomObject]@{ Name = "Block Office applications from creating executable content"; GUID = "3B576869-A4EC-4529-8536-B80A7769E899" },
        [PSCustomObject]@{ Name = "Block Office applications from injecting code into other processes"; GUID = "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84" },
        [PSCustomObject]@{ Name = "Block JavaScript or VBScript from launching downloaded executable content"; GUID = "D3E037E1-3EB8-44C8-A917-57927947596D" },
        [PSCustomObject]@{ Name = "Block execution of potentially obfuscated scripts"; GUID = "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC" },
        [PSCustomObject]@{ Name = "Block Win32 API calls from Office macros"; GUID = "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B" },
        [PSCustomObject]@{ Name = "Block executable files from running unless they meet a prevalence, age, or trusted list criterion"; GUID = "01443614-cd74-433a-b99e-2ecdc07bfc25" },
        [PSCustomObject]@{ Name = "Use advanced protection against ransomware"; GUID = "c1db55ab-c21a-4637-bb3f-a12568109d35" },
        [PSCustomObject]@{ Name = "Block credential stealing from the Windows local security authority subsystem (lsass.exe)"; GUID = "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2" },
        [PSCustomObject]@{ Name = "Block process creations originating from PSExec and WMI commands"; GUID = "d1e49aac-8f56-4280-b9ba-993a6d77406c" },
        [PSCustomObject]@{ Name = "Block untrusted and unsigned processes that run from USB"; GUID = "b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4" },
        [PSCustomObject]@{ Name = "Block Office communication application from creating child processes"; GUID = "26190899-1602-49e8-8b27-eb1d0a1ce869" },
        [PSCustomObject]@{ Name = "Block Adobe Reader from creating child processes"; GUID = "7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c" },
        [PSCustomObject]@{ Name = "Block persistence through WMI event subscription"; GUID = "e6db77e5-3df2-4cf1-b95a-636979351e5b" },
        [PSCustomObject]@{ Name = "Block abuse of exploited vulnerable signed drivers"; GUID = "56a863a9-875e-4185-98a7-b882c64b5ce5" },
        [PSCustomObject]@{ Name = "Block rebooting machine in Safe Mode (preview)"; GUID = "33ddedf1-c6e0-47cb-833e-de6133960387" },
        [PSCustomObject]@{ Name = "Block use of copied or impersonated system tools (preview)"; GUID = "c0033c00-d16d-4114-a5a0-dc9b3a7d2ceb" },
        [PSCustomObject]@{ Name = "Block Webshell creation for Servers"; GUID = "a8f5898e-1dc8-49a9-9878-85004b8a61e6" }
    )

    # Get the ASR rules on the device
    try {
        $ASRRUlesOnDevice = ((Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Policy Manager" -ErrorAction SilentlyContinue).asrrules).split("|")
    } catch {
        Write-Host "Requested registry access is not allowed." -ForegroundColor Red
        break
    }
    $ASRRUlesOnDeviceCount = ($ASRRUlesOnDevice | Where-Object { $_ -match "=" }).Count               # Count the number of ASR rules on the device (=1, =2, =6, =0)

    if ($ASRRUlesOnDeviceCount -gt 0) {
        # Define the values
        $enabledvalues = @{
            "Not Configured/Disabled" = 0
            "Enabled"                 = 1
            "Audit"                   = 2
            "Warn"                    = 6
        }

        $ASROnDeviceResults = @()
        foreach ($rule in $asrrules) {
            $Found = $ASRRUlesOnDevice | Where-Object { $_ -match $($rule.GUID) } 

            if ($found) {
                $ruleValue = $Found.Split("=")[1]
                $status = $enabledvalues.GetEnumerator() | Where-Object { $_.Value -eq $ruleValue } | Select-Object -ExpandProperty Key
                if (-not $status) {
                    $status = "Unknown"
                }
                $ASROnDeviceResults += [PSCustomObject]@{
                    Name   = $rule.Name
                    GUID   = $rule.GUID
                    Value  = $ruleValue
                    Status = $status
                }
            } else {
                $ASROnDeviceResults += [PSCustomObject]@{
                    Name   = $rule.Name
                    GUID   = $rule.GUID
                    Value  = $null
                    Status = "Not Configured"
                }
            }
        }
        Return $ASROnDeviceResults

    }
}
function Get-ASRStatusExclusions {
    # Find all exclusions
    Try {
        $ASRExclusions = Get-Item "HKLM:\SOFTWARE\Microsoft\Windows Defender\Windows Defender Exploit Guard\ASR\ASROnlyExclusions" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property

        if ($ASRExclusions.count -eq 0) {
            $ASRExclusionsResults = "No ASR exclusions found"
            $skipsteps = $true
            Return $ASRExclusionsResults
        }
    } catch {
        $SkipSteps = $true
        $ASRExclusionsResults = "No ASR exclusions found"
        Return $ASRExclusionsResults
    }

    if (-not($SkipSteps)) {
        $ASRExclusionResults = @()
        foreach ($exclusion in $ASRExclusions) {
            $type = if ($exclusion -match "\.\w+$") { "File" } else { "Folder" }

            if ($type -eq "Folder") {
                $files = (Get-ChildItem -Path $exclusion -Recurse -Force).fullname 
                foreach ($file in $files) {
                    if ($file -match "\.\w+$") {
                        $ASRExclusionResults += [PSCustomObject]@{
                            Type = "File"
                            Path = $file
                        }
                    } else {
                        $ASRExclusionResults += [PSCustomObject]@{
                            Type = "Folder"
                            Path = $exclusion
                        }
                    }
                }
            }
            $ASRExclusionResults = $ASRExclusionResults | Sort-Object Type, Path -Descending
        }
    }
    Return $ASRExclusionResults
}

function get-CFAStatus {
    try {
       $CFAStatus = Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access" -Name EnableControlledFolderAccess
    } catch {
        $SkipSteps = $true
        $CFAStatusResults = "Controlled Folder Access is not enabled"
        Return $CFAStatusResults
    }

    if (-not ($SkipSteps)) {
    $enabledvalues = @{
        "Not Configured/Disabled"                   = 0
        "Enabled"                     = 1
        "Audit"                       = 2
        "AuditDiskModificationOnly"   = 4
        "BlockDiskModificationOnly"   = 3
    }

    if ($CFAStatus) {
        $CFAStatus = $enabledvalues.GetEnumerator() | Where-Object { $_.Value -eq $CFAStatus } | Select-Object -ExpandProperty Key
    } else {
        $CFAStatus = "Not Configured/Disabled"
    }

    $ProtectedFolders = Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access\ProtectedFolders\" -ErrorAction SilentlyContinue  | Select-Object -ExpandProperty Property | Sort-Object
    $ProtectedApplications = Get-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows Defender\Windows Defender Exploit Guard\Controlled Folder Access\AllowedApplications\" -ErrorAction SilentlyContinue  | Select-Object -ExpandProperty Property | Sort-Object
    
    $CFAStatusResults = @()

    $CFAStatusResults += [PSCustomObject]@{
        Type  = "Controlled Access Folder Status"
        Value = $CFAStatus
    }

    if ($ProtectedFolders) {
        foreach ($folder in $ProtectedFolders) {
            $CFAStatusResults += [PSCustomObject]@{
                Type = "Protected Folder"
                Value = $folder
            }
        }
    }

    if ($ProtectedApplications) {
        foreach ($application in $ProtectedApplications) {
            $CFAStatusResults += [PSCustomObject]@{
                Type = "Protected Application"
                Value = $application
            }
        }
    }

    Return $CFAStatusResults
    } 
} 

Clear-Host

$banner = @"

    █████╗ ███████╗██████╗     ██████╗ ██╗   ██╗██╗     ███████╗    ██╗███╗   ██╗███████╗██████╗ ███████╗ ██████╗████████╗ ██████╗ ██████╗ 
    ██╔══██╗██╔════╝██╔══██╗    ██╔══██╗██║   ██║██║     ██╔════╝    ██║████╗  ██║██╔════╝██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔═══██╗██╔══██╗
    ███████║███████╗██████╔╝    ██████╔╝██║   ██║██║     █████╗      ██║██╔██╗ ██║███████╗██████╔╝█████╗  ██║        ██║   ██║   ██║██████╔╝
    ██╔══██║╚════██║██╔══██╗    ██╔══██╗██║   ██║██║     ██╔══╝      ██║██║╚██╗██║╚════██║██╔═══╝ ██╔══╝  ██║        ██║   ██║   ██║██╔══██╗
    ██║  ██║███████║██║  ██║    ██║  ██║╚██████╔╝███████╗███████╗    ██║██║ ╚████║███████║██║     ███████╗╚██████╗   ██║   ╚██████╔╝██║  ██║
    ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝    ╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚══════╝    ╚═╝╚═╝  ╚═══╝╚══════╝╚═╝     ╚══════╝ ╚═════╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝

"@

$ASRRulesOnDevice_Count = (Get-ASRStatus).count
$ASRRulesOnDevice_Count_Configured = (Get-ASRStatus | Where-Object { $_.Status -ne "Not Configured" }).count

if ($ASRRUlesOnDevice_Count -eq 0) {
    Write-Host $banner -ForegroundColor Yellow
    Write-Host "No ASR rules found on the device" -ForegroundColor Red
    Return
} 

if ($ASRRUlesOnDevice_Count -gt 0) {
    Write-Host $banner -ForegroundColor Yellow 
    Write-Host "FOUND: $ASRRUlesOnDevice_Count_Configured of $ASRRUlesOnDevice_Count ASR rules on the device" -ForegroundColor Yellow
    Get-ASRStatus | Format-Table -AutoSize

    Write-Host "Exclusions`n" -ForegroundColor Yellow -BackgroundColor Black -NoNewline
    Get-ASRStatusExclusions | Format-Table -AutoSize

    Write-Host "Controlled Folder Access`n" -ForegroundColor Yellow -BackgroundColor Black -NoNewline
    get-CFAStatus | Format-Table -AutoSize
}
