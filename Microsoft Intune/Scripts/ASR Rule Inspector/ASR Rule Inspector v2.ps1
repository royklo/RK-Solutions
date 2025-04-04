function Test-AdminElevation {
    # Check for elevated permissions
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "Please run the script as an Administrator." -ForegroundColor Red
        return $false
    }
    return $true
}

function New-HTMLReport {
    param (
        [Parameter(Mandatory = $true)]
        [array]$ASRRules,
        [array]$DuplicateASRRules,
        [array]$ASRExclusions,
        [array]$DuplicateASRExclusions,
        [hashtable]$CFAStatus
    )

    # Initialize HTML content
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ASR Rule Inspection Report</title>
    <link rel="stylesheet" href="https://cdn.datatables.net/1.13.6/css/jquery.dataTables.min.css">
    <script src="https://code.jquery.com/jquery-3.7.1.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #121212;
            color: #e0e0e0;
            line-height: 1.6;
            font-size: 14px;
        }
        header {
            background: linear-gradient(90deg, #1f1f1f, #3a3a3a);
            padding: 20px;
            text-align: center;
            border-bottom: 2px solid #00bcd4;
        }
        header h1 {
            color: #00bcd4;
            font-size: 24px;
            margin: 0;
        }
        h2 {
            color: #00e676;
            font-size: 20px;
            margin-top: 20px;
        }
        h3 {
            color: #81d4fa;
            font-size: 16px;
            margin-top: 10px;
            font-weight: 300;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
            font-size: 14px;
            background-color: #1e1e1e;
            border: 1px solid #333;
        }
        th, td {
            padding: 10px;
            text-align: left;
            border: 1px solid #333;
        }
        th {
            background-color: #00bcd4;
            color: #121212;
            text-transform: uppercase;
        }
        tr:nth-child(even) {
            background-color: #2a2a2a;
        }
        tr:hover {
            background-color:rgb(34, 111, 131);
            color: #121212;
        }
        .match {
            color: #00e676; /* Green for match */
            font-weight: bold;
        }
        .no-match {
            color: #ff5252; /* Red for no match */
            font-weight: bold;
        }
        .warning {
            color: #ffa500; /* Orange for warning */
            font-weight: bold;
        }
        .duplicate {
            color: #ffeb3b; /* Yellow for duplicates */
            font-weight: bold;
        }
        footer {
            text-align: center;
            padding: 10px;
            background: linear-gradient(90deg, #3a3a3a, #1f1f1f);
            color: #757575;
            margin-top: 20px;
            border-top: 2px solid #00bcd4;
        }
        footer p {
            margin: 0;
            font-size: 12px;
        }
    </style>
</head>
<body>
    <header>
        <h1>ASR Rule Inspection Report</h1>
    </header>
"@

    # Add ASR Rules table
    if ($ASRRules) {
        $html += "<h2>ASR Rules</h2>"
        $html += "<table id='ASRRules'><thead><tr><th>Policy</th><th>Policy Type</th><th>Name</th><th>GUID</th><th>Intune Status</th><th>Local Status</th><th>Result</th></tr></thead><tbody>"
        foreach ($rule in $ASRRules) {
            $resultClass = switch ($rule.Result) {
                "Match" { "match" }
                "Warning" { "warning" }
                "Duplicate" { "duplicate" }
                "Conflict" { "duplicate" }
                default { "no-match" }
            }
            $html += "<tr><td>$($rule.Policy)</td><td>$($rule.'Policy Type')</td><td>$($rule.Name)</td><td>$($rule.GUID)</td><td>$($rule.'Intune Status')</td><td>$($rule.'Local Status')</td><td><span class='$resultClass'>$($rule.Result)</span></td></tr>"
        }
        $html += "</tbody></table>"
    }

    # Add Duplicate ASR Rules table
    if ($DuplicateASRRules) {
        $html += "<h2>Duplicate/Conflicting ASR Rules</h2>"
        $html += "<table id='DuplicateASRRules'><thead><tr><th>Policy</th><th>Policy Type</th><th>Name</th><th>GUID</th><th>Intune Status</th><th>Result</th></tr></thead><tbody>"
        foreach ($rule in $DuplicateASRRules) {
            $html += "<tr><td>$($rule.Policy)</td><td>$($rule.'Policy Type')</td><td>$($rule.Name)</td><td>$($rule.GUID)</td><td>$($rule.'Intune Status')</td><td><span class='duplicate'>$($rule.Result)</span></td></tr>"
        }
        $html += "</tbody></table>"
    }

    # Add ASR Exclusions table
    if ($ASRExclusions) {
        $html += "<h2>ASR Rule Exclusions</h2>"
        $html += "<table id='ASRExclusions'><thead><tr><th>Policy Name</th><th>Policy Type</th><th>Intune Path</th><th>Local Path</th><th>Type</th><th>Result</th><th>Note</th></tr></thead><tbody>"
        foreach ($exclusion in $ASRExclusions) {
            $resultClass = switch ($exclusion.Result) {
                "Match" { "match" }
                "Warning" { "warning" }
                "Duplicate" { "duplicate" }
                "Conflict" { "duplicate" }
                default { "no-match" }
            }
            $html += "<tr><td>$($exclusion.PolicyName)</td><td>$($exclusion.PolicyType)</td><td>$($exclusion.IntunePath)</td><td>$($exclusion.LocalPath)</td><td>$($exclusion.Type)</td><td class='$resultClass'>$($exclusion.Result)</td><td>$($exclusion.Note)</td></tr>"
        }
        $html += "</tbody></table>"
    }

    # Add Duplicate ASR Exclusions table
    if ($DuplicateASRExclusions) {
        $html += "<h2>Duplicate/Conflicting ASR Exclusions</h2>"
        $html += "<table id='DuplicateASRExclusions'><thead><tr><th>Policy Name</th><th>Policy Type</th><th>Intune Path</th><th>Local Path</th><th>Type</th><th>Result</th><th>Note</th></tr></thead><tbody>"
        foreach ($exclusion in $DuplicateASRExclusions) {
            $html += "<tr><td>$($exclusion.PolicyName)</td><td>$($exclusion.PolicyType)</td><td>$($exclusion.IntunePath)</td><td>$($exclusion.LocalPath)</td><td>$($exclusion.Type)</td><td class='duplicate'>$($exclusion.Result)</td><td>$($exclusion.Note)</td></tr>"
        }
        $html += "</tbody></table>"
    }

    # Add Controlled Folder Access tables (using updated structure)
    if ($CFAStatus) {
        if ($CFAStatus.CFAStatusReport) {
            $html += "<h2>Controlled Folder Access Status</h2>"
            $html += "<table id='CFAStatus'><thead><tr><th>Policy Name</th><th>Policy Type</th><th>Type</th><th>Intune Value</th><th>Local Value</th><th>Result</th><th>Note</th></tr></thead><tbody>"
            foreach ($status in $CFAStatus.CFAStatusReport) {
                $resultClass = switch ($status.Result) {
                    "Match" { "match" }
                    "Warning" { "warning" }
                    "Duplicate" { "duplicate" }
                    "Conflict" { "duplicate" }
                    default { "no-match" }
                }
                $html += "<tr><td>$($status.PolicyName)</td><td>$($status.PolicyType)</td><td>$($status.Type)</td><td>$($status.IntuneValue)</td><td>$($status.LocalValue)</td><td class='$resultClass'>$($status.Result)</td><td>$($status.Note)</td></tr>"
            }
            $html += "</tbody></table>"
        }

        if ($CFAStatus.SameCFAReport) {
            $html += "<h2>Duplicate/Conflicting Controlled Folder Access</h2>"
            $html += "<table id='SameCFAReport'><thead><tr><th>Policy Name</th><th>Policy Type</th><th>Type</th><th>Intune Value</th><th>Local Value</th><th>Result</th><th>Note</th></tr></thead><tbody>"
            foreach ($conflict in $CFAStatus.SameCFAReport) {
                $html += "<tr><td>$($conflict.PolicyName)</td><td>$($conflict.PolicyType)</td><td>$($conflict.Type)</td><td>$($conflict.IntuneValue)</td><td>$($conflict.LocalValue)</td><td class='duplicate'>$($conflict.Result)</td><td>$($conflict.Note)</td></tr>"
            }
            $html += "</tbody></table>"
        }
    }

    # Close HTML content
    $html += @"
    <footer>
        <p>Generated by Roy Klooster -  ASR Rule Inspection Tool</p>
        <p>&copy; 2025 RK Solutions. All rights reserved.</p>
    </footer>
    <script>
        \$\(document\).ready(function() {
            \$\('table'\).DataTable();
        });
    </script>
</body>
</html>
"@

    # Save the HTML report
    $documentsPath = [Environment]::GetFolderPath("MyDocuments")
    $reportPath = Join-Path -Path $documentsPath -ChildPath "ASRRuleInspectionReport.html"
    $html | Out-File -FilePath $reportPath -Encoding UTF8
    Write-Host "Report generated: $reportPath" -ForegroundColor Green

    # Open the HTML report automatically
    Start-Process -FilePath $reportPath
}
Function Install-Requirements {
    # Check if the required modules are installed
    $requiredModules = @("Microsoft.Graph.DeviceManagement", "Microsoft.Graph.Authentication", "Microsoft.Graph.Identity.DirectoryManagement","Microsoft.Graph.Users", "Microsoft.Graph.Beta.DeviceManagement")
    foreach ($module in $requiredModules) {
        if (-not (Get-Module -ListAvailable -Name $module)) {
            Write-Host "Installing module: $module" -ForegroundColor Cyan
            Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
        }
    }

    # Import the required modules
    foreach ($module in $requiredModules) {
        try {
            Import-Module -Name $module -Force -ErrorAction SilentlyContinue
            Write-Host "Module $module imported successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to import module $module $_" -ForegroundColor Red
            throw
        }
    }

}

function Ensure-MgGraphConnection {
    Clear-Host

    # Authentication 
    $AuthenticationScope = @(
        "DeviceManagementConfiguration.Read.All",
        "DeviceManagementManagedDevices.Read.All",
        "Device.Read.All",
        "User.Read.All",
        "GroupMember.Read.All",
        "Directory.Read.All"
    )

    Connect-MgGraph -Scopes $AuthenticationScope -NoWelcome

    $Contextinfo = (Get-MgContext)
        
    if ($Contextinfo) {
        # Disconnect any active sessions
        Disconnect-MgGraph | Out-Null
        Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Green

        # Reconnect to Microsoft Graph
        Connect-MgGraph -Scopes $AuthenticationScope -NoWelcome
    }

        
    Start-Sleep -Seconds 2
    Clear-Host
}

Function Get-IntuneConfiguredASRRules {
    [CmdletBinding()]
    Param()

    # Define the setting definition IDs you want to filter
    $SettingDefinitionIDs = @(
        "device_vendor_msft_policy_config_defender_controlledfolderaccessallowedapplications",
        "device_vendor_msft_policy_config_defender_controlledfolderaccessprotectedfolders",
        "device_vendor_msft_policy_config_defender_enablecontrolledfolderaccess",
        "device_vendor_msft_policy_config_defender_attacksurfacereductionrules"
    )

    # Initialize an empty array to store filtered policies
    $script:AllPolicies = @()

    # Retrieve all policies first
    $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies"

    try {
        do {
            # Make the request to get policies
            $response = Invoke-MgGraphRequest -Method GET -Uri $uri

            # Filter policies that have assignments
            $policiesWithAssignments = $response.value | Where-Object {
                $policyId = $_.id
                $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')/assignments"
                $assignmentResponse = Invoke-MgGraphRequest -Method GET -Uri $assignmentsUri
                $assignmentResponse.value.Count -gt 0
            }

            # For each policy with assignments, expand settings
            foreach ($policy in $policiesWithAssignments) {
                $settingsUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$($policy.id)')?`$expand=settings"
                $policyWithSettings = Invoke-MgGraphRequest -Method GET -Uri $settingsUri

                # Check if any setting matches the desired definition IDs
                $matchingSettings = $policyWithSettings.settings.values | 
                Where-Object { $SettingDefinitionIDs -contains $_.settingDefinitionId }

                if ($matchingSettings) {
                    $script:AllPolicies += $policyWithSettings
                }
            }

            # Get the next page URI, if any
            $uri = $response.'@odata.nextLink'

            # If there's a next page, show progress
            if ($uri) {
                Write-Host "Retrieved $($script:AllPolicies.Count) filtered policies so far, looking for more..."
            }

        } while ($uri)

        # Display the total count of filtered policies
        Write-Host "Total filtered policies retrieved: $($script:AllPolicies.Count)"
    }
    catch {
        Write-Host "Error retrieving policies from Microsoft Graph API: $_" -ForegroundColor Red
        return @()
    }


    #ASR Rule settings
    $script:IntuneConfigurableASRRules = @(
        [PSCustomObject]@{ 
            Name                 = "Block executable content from email client and webmail"; 
            GUID                 = "BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockexecutablecontentfromemailclientandwebmail" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block all Office applications from creating child processes"; 
            GUID                 = "D4F940AB-401B-4EFC-AADC-AD5F3C50688A"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockallofficeapplicationsfromcreatingchildprocesses" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block Office applications from creating executable content"; 
            GUID                 = "3B576869-A4EC-4529-8536-B80A7769E899"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockofficeapplicationsfromcreatingexecutablecontent" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block Office applications from injecting code into other processes"; 
            GUID                 = "75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockofficeapplicationsfrominjectingcodeintootherprocesses" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block JavaScript or VBScript from launching downloaded executable content"; 
            GUID                 = "D3E037E1-3EB8-44C8-A917-57927947596D"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockjavascriptorvbscriptfromlaunchingdownloadedexecutablecontent" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block execution of potentially obfuscated scripts"; 
            GUID                 = "5BEB7EFE-FD9A-4556-801D-275E5FFC04CC"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockexecutionofpotentiallyobfuscatedscripts" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block Win32 API calls from Office macros"; 
            GUID                 = "92E97FA1-2EDF-4476-BDD6-9DD0B4DDDC7B"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockwin32apicallsfromofficemacros" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block executable files from running unless they meet a prevalence, age, or trusted list criterion"; 
            GUID                 = "01443614-cd74-433a-b99e-2ecdc07bfc25"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockexecutablefilesrunningunlesstheymeetprevalenceagetrustedlistcriterion" 
        },
        [PSCustomObject]@{ 
            Name                 = "Use advanced protection against ransomware"; 
            GUID                 = "c1db55ab-c21a-4637-bb3f-a12568109d35"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_useadvancedprotectionagainstransomware" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block credential stealing from the Windows local security authority subsystem (lsass.exe)"; 
            GUID                 = "9e6c4e1f-7d60-472f-ba1a-a39ef669e4b2"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockcredentialstealingfromwindowslocalsecurityauthoritysubsystem" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block process creations originating from PSExec and WMI commands"; 
            GUID                 = "d1e49aac-8f56-4280-b9ba-993a6d77406c"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockprocesscreationsfrompsexecandwmicommands" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block untrusted and unsigned processes that run from USB"; 
            GUID                 = "b2b3f03d-6a65-4f7b-a9c7-1c7ef74a9ba4"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockuntrustedunsignedprocessesthatrunfromusb" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block Office communication application from creating child processes"; 
            GUID                 = "26190899-1602-49e8-8b27-eb1d0a1ce869"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockofficecommunicationappfromcreatingchildprocesses" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block Adobe Reader from creating child processes"; 
            GUID                 = "7674ba52-37eb-4a4f-a9a1-f0f9a1619a2c"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockadobereaderfromcreatingchildprocesses" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block persistence through WMI event subscription"; 
            GUID                 = "e6db77e5-3df2-4cf1-b95a-636979351e5b"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockpersistencethroughwmieventsubscription" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block abuse of exploited vulnerable signed drivers"; 
            GUID                 = "56a863a9-875e-4185-98a7-b882c64b5ce5"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockabuseofexploitedvulnerablesigneddrivers" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block rebooting machine in Safe Mode (preview)"; 
            GUID                 = "33ddedf1-c6e0-47cb-833e-de6133960387"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockrebootingmachineinsafemode" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block use of copied or impersonated system tools (preview)"; 
            GUID                 = "c0033c00-d16d-4114-a5a0-dc9b3a7d2ceb"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockuseofcopiedorimpersonatedsystemtools" 
        },
        [PSCustomObject]@{ 
            Name                 = "Block Webshell creation for Servers"; 
            GUID                 = "a8f5898e-1dc8-49a9-9878-85004b8a61e6"; 
            IntuneASRSettingName = "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_blockwebshellcreationforservers" 
        }
    )

    $script:enabledvalues = @{
        "off"   = @{
            RegeditValue      = 0
            IntuneValue       = "_off"
            FriendlyNameValue = "Not Configured/Disabled"
        }
        "block" = @{
            RegeditValue      = 1
            IntuneValue       = "_block"
            FriendlyNameValue = "Enabled"
        }
        "audit" = @{
            RegeditValue      = 2
            IntuneValue       = "_audit"
            FriendlyNameValue = "Audit"
        }
        "warn"  = @{
            RegeditValue      = 6
            IntuneValue       = "_warn"
            FriendlyNameValue = "Warn"
        }
    }

    $script:IntuneASRConfiguration = @()
    foreach ($policy in $script:AllPolicies) {
        try {
            $policyId = $policy.id
            $Assignments = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')/assignments"
            $AssignmentResponse = Invoke-MgGraphRequest -Method GET -Uri $Assignments
            $PolicyAssignments = $null -ne $AssignmentResponse.value

            if ($PolicyAssignments) {
                $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')?`$expand=settings"
                $response = Invoke-MgGraphRequest -Method GET -Uri $uri
                $policy.settings = $response.settings
                        
                $PolicyType = if ($policy.templateReference.templateFamily -eq "endpointSecurityAttackSurfaceReduction") {
                    "Endpoint Security"
                }
                elseif ($policy.templateReference.templateFamily -eq "none") {
                    "Configuration Profile"
                }
                else {
                    "Other"
                }

                $settings = ($policy.settings.values | Where-Object { $_.settingDefinitionId -eq "device_vendor_msft_policy_config_defender_attacksurfacereductionrules" }).groupSettingCollectionValue.children.choiceSettingValue.value

                foreach ($setting in $settings) {
                    $parts = $setting -split '_'

                    # Extract the last two parts
                    $settingName = $parts[-2]  
                    $settingValue = $parts[-1]  
            
                    $matchingRule = $script:IntuneConfigurableASRRules | Where-Object { $_.IntuneASRSettingName -match $settingName }
                    if ($matchingRule) {
                        $settingName = $settingName -replace "device_vendor_msft_policy_config_defender_attacksurfacereductionrules_", ""

                        $script:IntuneASRConfiguration += [PSCustomObject]@{
                            PolicyName      = $policy.name
                            PolicyType      = $PolicyType
                            ASRRuleName     = $matchingRule.Name
                            ASRRuleGUID     = $matchingRule.GUID
                            ConfiguredValue = $script:enabledvalues[$settingValue]
                        }
                    }
                }
            }
        }
        catch {
            Write-Host "Error processing policy $($policy.name): $_" -ForegroundColor Yellow
            continue
        }
    }
    return $script:IntuneASRConfiguration | Sort-Object -Property PolicyName

}

Function Find-DuplicateASRRules {
    if (-not $script:IntuneASRConfiguration) {
        Write-Host "No Duplicates found. Because there are no ASR rules configured." -ForegroundColor Yellow
        return
    }
    # Check for conflicting ASR rules
    $SameASRRules = $script:IntuneASRConfiguration | Group-Object -Property ASRRuleGUID | Where-Object { $_.Count -gt 1 } 

    $SameRulesReport = @()
    foreach ($same in $SameASRRules) {
        $conflict = ($same.Group.ConfiguredValue.FriendlyNameValue | Sort-Object -Unique).Count -gt 1
        $result = if ($conflict) { "Conflict" } else { "Duplicate" }
        $same.Group | ForEach-Object {
            $SameRulesReport += [PSCustomObject]@{
                Policy          = $_.PolicyName
                "Policy Type"   = $_.PolicyType
                Name            = $_.ASRRuleName
                GUID            = $_.ASRRuleGUID
                "Intune Status" = $_.ConfiguredValue.FriendlyNameValue
                Result          = $result
            }
                    
        }     
    }
    return $SameRulesReport
}

Function Get-ASRStatus {
    [CmdletBinding()]
    Param()

    # Get the ASR rules on the device using Get-MpPreference
    try {
        $mpPreference = Get-MpPreference
        $LocalFoundASRRules = @{}
        if ($mpPreference.AttackSurfaceReductionRules_Ids -and $mpPreference.AttackSurfaceReductionRules_Actions) {
            for ($i = 0; $i -lt $mpPreference.AttackSurfaceReductionRules_Ids.Count; $i++) {
                $LocalFoundASRRules[$mpPreference.AttackSurfaceReductionRules_Ids[$i]] = $mpPreference.AttackSurfaceReductionRules_Actions[$i]
            }
        }
    }
    catch {
        Write-Host "Unable to retrieve ASR rules using Get-MpPreference: $_" -ForegroundColor Red
        return @()
    }

    if ($LocalFoundASRRules.Count -eq 0) {
        Write-Host "No ASR rules found on the device." -ForegroundColor Yellow
        return @()
    }

    $ASROnDeviceResults = @()
    foreach ($rule in $script:IntuneConfigurableASRRules) {
        if ($LocalFoundASRRules.ContainsKey($rule.GUID)) {
            $ruleValue = $LocalFoundASRRules[$rule.GUID]
            $localStatus = ($script:enabledvalues.values | Where-Object { $_.RegeditValue -eq $ruleValue }).FriendlyNameValue
            if (-not $localStatus) {
                $localStatus = "Unknown"
            }
            $IntuneMatches = $script:IntuneASRConfiguration | Where-Object { $_.ASRRuleGUID -eq $rule.GUID }
            if ($IntuneMatches) {
                foreach ($IntuneMatch in $IntuneMatches) {
                    $intuneConfiguredValue = $IntuneMatch.ConfiguredValue.FriendlyNameValue
                    $matchesIntuneConfig = if ($localStatus -eq $intuneConfiguredValue) { "Match" } else { "No Match" }
                    $ASROnDeviceResults += [PSCustomObject]@{
                        Policy          = $IntuneMatch.PolicyName
                        "Policy Type"   = $IntuneMatch.PolicyType
                        Name            = $rule.Name
                        GUID            = $rule.GUID
                        "Intune Status" = $intuneConfiguredValue
                        "Local Status"  = $localStatus
                        "Result"        = $matchesIntuneConfig
                    }
                }
            }
            else {
                $ASROnDeviceResults += [PSCustomObject]@{
                    Policy          = "Not Configured"
                    Name            = $rule.Name
                    "Policy Type"   = "Not Configured"
                    GUID            = $rule.GUID
                    "Intune Status" = "Not Configured"
                    "Local Status"  = $localStatus
                    "Result"        = "No Match"
                }
            }
        }
        elseif ($IntuneMatches) {
            foreach ($IntuneMatch in $IntuneMatches) {
                $ASROnDeviceResults += [PSCustomObject]@{
                    Policy          = $IntuneMatch.PolicyName
                    "Policy Type"   = $IntuneMatch.PolicyType
                    Name            = $rule.Name
                    GUID            = $rule.GUID
                    "Intune Status" = $IntuneMatch.ConfiguredValue.FriendlyNameValue
                    "Local Status"  = "Not Configured"
                    "Result"        = "No Match"
                }
            }
        }
    }
    Return $ASROnDeviceResults | Sort-Object -Property Policy, Name
}

function Get-ASRStatusExclusions {

    $matchingPolicies = $script:AllPolicies | Where-Object {
        $_.settings.values | Where-Object { $_.settingDefinitionId -eq "device_vendor_msft_policy_config_defender_attacksurfacereductiononlyexclusions" }
    }

    if ($matchingPolicies.Count -eq 0) {
        Write-Host "No policies found with the specified setting definition ID." -ForegroundColor Yellow
        return @()
    }

    $IntuneASRExclusions = @()
    foreach ($policy in $matchingPolicies) {
        $policyId = $policy.id
        $Assignments = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')/assignments"
        $AssignmentResponse = Invoke-MgGraphRequest -Method GET -Uri $Assignments
        $PolicyAssignments = $null -ne $AssignmentResponse.value

        if ($PolicyAssignments) {
            $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')?`$expand=settings"
            $response = Invoke-MgGraphRequest -Method GET -Uri $uri
            $policy.settings = $response.settings

            $settings = (($policy.settings.settinginstance | Where-Object { $_.SettingDefinitionId -eq "device_vendor_msft_policy_config_defender_attacksurfacereductiononlyexclusions" }).simpleSettingCollectionValue).value

            foreach ($ExcludedPath in $settings) {
                if ($ExcludedPath -match "\.\w+$") {
                    $IntuneASRExclusions += [PSCustomObject]@{ Type = "File"; Path = $ExcludedPath }
                }
                else {
                    $IntuneASRExclusions += [PSCustomObject]@{ Type = "Folder"; Path = $ExcludedPath }
                    Get-ChildItem -Path $ExcludedPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                        $IntuneASRExclusions += [PSCustomObject]@{ Type = "File"; Path = $_.FullName }
                    }
                }
            }
        }
    }


    try {
        $ASRExclusions = (Get-MpPreference).AttackSurfaceReductionOnlyExclusions

        if (-not $ASRExclusions -or $ASRExclusions.Count -eq 0) {
            return "No ASR exclusions found"
        }
    }
    catch {
        return "Error retrieving ASR exclusions: $_"
    }

    $ASRExclusionResults = foreach ($exclusion in $ASRExclusions) {
        if (Test-Path $exclusion) {
            if ($exclusion -match "\.\w+$") {
                [PSCustomObject]@{ Type = "File"; Path = $exclusion }
            }
            else {
                [PSCustomObject]@{ Type = "Folder"; Path = $exclusion }
                Get-ChildItem -Path $exclusion -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    [PSCustomObject]@{ Type = "File"; Path = $_.FullName }
                }
            }
        }
        else {
            [PSCustomObject]@{ Type = "Not Existing"; Path = $exclusion }
        }
    }

    $global:ASRExclusionsReport += $ASRExclusionResults | Sort-Object Type, Path

    $global:ASRExclusionsReport = @()
    $global:SameExclusionsReport = @()
  
    foreach ($Rule in $IntuneASRExclusions) {
        $existsLocally = Test-Path $Rule.Path
        $matchingPoliciesForRule = $matchingPolicies | Where-Object {
            $_.settings.values | Where-Object { $_.settingDefinitionId -eq "device_vendor_msft_policy_config_defender_attacksurfacereductiononlyexclusions" } |
            Where-Object { $_.simpleSettingCollectionValue.value -contains $Rule.Path }
        }
  
        if ($matchingPoliciesForRule.Count -gt 0) {
            foreach ($policyDetails in $matchingPoliciesForRule) {
                $result = if ($existsLocally) { "Match" } else { "No Match" }
                $note = if ($result -eq "No Match" -and -not $existsLocally) { "Path does not exist locally" }
  
                if ($Rule.Type -eq "Folder" -and $existsLocally) {
                    $childItems = Get-ChildItem -Path $Rule.Path -Recurse -Force -ErrorAction SilentlyContinue
                    if ($childItems) {
                        $result = "Match"
                        $note = "Child items found"
                    }
                }
  
                $policyName = $policyDetails.name
                $policyType = switch ($policyDetails.templateReference.templateFamily) {
                    "endpointSecurityAttackSurfaceReduction" { "Endpoint Security" }
                    "none" { "Configuration Profile" }
                    default { "Other" }
                }
  
                $global:ASRExclusionsReport += [PSCustomObject]@{
                    PolicyName = $policyName
                    PolicyType = $policyType
                    IntunePath = $Rule.Path
                    LocalPath  = if ($existsLocally) { $Rule.Path } else { "Not Found" }
                    Type       = $Rule.Type
                    Result     = $result
                    Note       = $note
                }
            }
        }
        else {
            $result = "No Match"
            $note = "No matching rule found in Intune exclusions"
  
            if ($Rule.Type -eq "File" -and $existsLocally) {
                $parentFolder = $IntuneASRExclusions | Where-Object { $_.Type -eq "Folder" -and $Rule.Path -like "$($_.Path)*" }
                if ($parentFolder) {
                    $result = "Warning"
                    $note = "Child item of matched folder: $($parentFolder.Path)"
                }
            }
  
            $global:ASRExclusionsReport += [PSCustomObject]@{
                PolicyName = "Not Configured"
                PolicyType = "Not Configured"
                IntunePath = $Rule.Path
                LocalPath  = if ($existsLocally) { $Rule.Path } else { "Not Found" }
                Type       = $Rule.Type
                Result     = $result
                Note       = $note
            }
        }
    }
  
    # Check for duplicate entries
    $duplicateGroups = $global:ASRExclusionsReport | Group-Object -Property IntunePath | Where-Object { $_.Count -gt 1 }
  
    foreach ($group in $duplicateGroups) {
        $conflictingResults = ($group.Group | Select-Object -Property Result -Unique).Count -gt 1
        $result = if ($conflictingResults) { "Conflict" } else { "Duplicate" }
  
        $uniquePolicyNameGroups = $group.Group | Group-Object -Property PolicyName
  
        foreach ($policyNameGroup in $uniquePolicyNameGroups) {
            $global:SameExclusionsReport += [PSCustomObject]@{
                PolicyName = $policyNameGroup.Group[0].PolicyName
                PolicyType = $policyNameGroup.Group[0].PolicyType
                IntunePath = $policyNameGroup.Group[0].IntunePath
                LocalPath  = $policyNameGroup.Group[0].LocalPath
                Type       = $policyNameGroup.Group[0].Type
                Result     = $result
                Note       = $policyNameGroup.Group[0].Note
            }
        }
    }
  
    # Modify ASRExclusionsReport to remove duplicate entries
    $global:ASRExclusionsReport = $global:ASRExclusionsReport | Group-Object -Property IntunePath | ForEach-Object {
        $group = $_.Group
        $uniquePolicyNameGroups = $group | Group-Object -Property PolicyName
        $uniquePolicyNameGroups | ForEach-Object { $_.Group | Select-Object -First 1 }
    }
  
    # Output the ASRExclusionsReport
    return @{
        ASRExclusionsReport  = $global:ASRExclusionsReport
        SameExclusionsReport = $global:SameExclusionsReport
    }
}

function get-CFAStatus {

    $SettingDefinitionIDs = @(
        "device_vendor_msft_policy_config_defender_controlledfolderaccessallowedapplications",
        "device_vendor_msft_policy_config_defender_controlledfolderaccessprotectedfolders",
        "device_vendor_msft_policy_config_defender_enablecontrolledfolderaccess"
    )

    $enabledvalues = @{
        "Not Configured/Disabled"   = 0
        "Enabled"                   = 1
        "Audit Mode"                = 2
        "AuditDiskModificationOnly" = 4
        "BlockDiskModificationOnly" = 3
    }

    $matchingPolicies = $script:AllPolicies | Where-Object {
        $_.settings.values | Where-Object { $_.settingDefinitionId -in $SettingDefinitionIDs }
    }

    $IntuneCFAPolicies = @()
    foreach ($policy in $matchingPolicies) {
        $policyId = $policy.id
        $Assignments = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')/assignments"
        $AssignmentResponse = Invoke-MgGraphRequest -Method GET -Uri $Assignments
        $PolicyAssignments = $null -ne $AssignmentResponse.value
    
        if ($PolicyAssignments) {
            $uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$policyId')?`$expand=settings"
            $response = Invoke-MgGraphRequest -Method GET -Uri $uri
            $policy.settings = $response.settings
    
            $settings = $policy.settings.values | Where-Object { $SettingDefinitionIDs -contains $_.settingDefinitionId }
    
            foreach ($setting in $settings) {
                $settingValue = $setting.simpleSettingCollectionValue.value
                if (-not $settingValue) {
                    $settingValue = $setting.choiceSettingValue.value
                }
                foreach ($value in $settingValue) {
                    $policyType = switch ($policy.templateReference.templateFamily) {
                        "endpointSecurityAttackSurfaceReduction" { "Endpoint Security" }
                        "none" { "Configuration Profile" }
                        default { "Other" }
                    }
    
                    $settingType = switch ($setting.settingDefinitionId) {
                        "device_vendor_msft_policy_config_defender_controlledfolderaccessprotectedfolders" { 
                            "Protected Folder"
                            $valueItem = $value
                        }
                        "device_vendor_msft_policy_config_defender_controlledfolderaccessallowedapplications" { 
                            "Allowed Application"
                            $valueItem = $value
                        }
                        "device_vendor_msft_policy_config_defender_enablecontrolledfolderaccess" { 
                            "Controlled Folder Access"
                            $settingValueParts = $value -split "_"
                            $lastPart = $settingValueParts[-1]
                            if ($lastPart -match '^\d+$') {
                                $valueItem = $enabledvalues.GetEnumerator() | 
                                Where-Object { $_.Value -eq [int]$lastPart } | 
                                Select-Object -ExpandProperty Key
                            }
                            else {
                                $valueItem = "Invalid Value"
                            }
                        }
                        default { 
                            "Unknown"
                            $valueItem = $value
                        }
                    }
    
                    $intunecfapolicies += [PSCustomObject]@{
                        PolicyName = $policy.name
                        PolicyType = $policyType
                        Value      = $valueItem
                        Type       = $settingType
                    }
                }
            }
        }
    }
    
    #$IntuneCFAPolicies | sort-object Type, PolicyName | Format-Table -AutoSize


    $CFAPreferences = get-mppreference

    $CFAStatus = $CFAPreferences.EnableControlledFolderAccess

    if ($CFAStatus) {
        $CFAStatus = $enabledvalues.GetEnumerator() | Where-Object { $_.Value -eq $CFAStatus } | Select-Object -ExpandProperty Key
    }
    else {
        $CFAStatus = "Not Configured/Disabled"
    }

    $CFAStatusResults = @()

    $CFAStatusResults += [PSCustomObject]@{
        Type  = "Controlled Access Folder Status"
        Value = $CFAStatus
    }

    $ProtectedFolders = @()
    if ($CFAPreferences.ControlledFolderAccessProtectedFolders) {
        foreach ($folder in $CFAPreferences.ControlledFolderAccessProtectedFolders) {
            $ProtectedFolders += [PSCustomObject]@{
                Type  = "Protected Folder"
                Value = $folder
            }
        }
    }

    $ProtectedApplications = @()
    if ($CFAPreferences.ControlledFolderAccessAllowedApplications) {
        foreach ($application in $CFAPreferences.ControlledFolderAccessAllowedApplications) {
            $ProtectedApplications += [PSCustomObject]@{
                Type  = "Protected Application"
                Value = $application
            }
        }
    }

    $MatchedCFAResults = @()

    foreach ($CFAItem in $IntuneCFAPolicies) {
        if ($CFAItem.Type -eq "Controlled Folder Access") {
            $result = if ($CFAItem.Value -eq $CFAStatus) { "Match" } else { "No Match" }
            $note = if ($result -eq "No Match") { "CFA status does not match Intune configuration" }
            $MatchedCFAResults += [PSCustomObject]@{
                PolicyName  = $CFAItem.PolicyName
                PolicyType  = $CFAItem.PolicyType
                Type        = $CFAItem.Type
                IntuneValue = $CFAItem.Value
                LocalValue  = $CFAStatus
                Result      = $result
                Note        = $note
            }
        }
        elseif ($CFAItem.Type -eq "Protected Folder") {
            $existsLocally = $ProtectedFolders | Where-Object { $_.Value -eq $CFAItem.Value }
            $result = if ($existsLocally) { "Match" } else { "No Match" }
            $note = if ($result -eq "No Match") { "Protected folder not found locally" }
            $MatchedCFAResults += [PSCustomObject]@{
                PolicyName  = $CFAItem.PolicyName
                PolicyType  = $CFAItem.PolicyType
                Type        = $CFAItem.Type
                IntuneValue = $CFAItem.Value
                LocalValue  = $existsLocally.Value
                Result      = $result
                Note        = $note
            }
        }
        elseif ($CFAItem.Type -eq "Allowed Application") {
            $existsLocally = $ProtectedApplications | Where-Object { $_.Value -eq $CFAItem.Value }
            $result = if ($existsLocally) { "Match" } else { "No Match" }
            $note = if ($result -eq "No Match") { "Allowed application not found locally" }
            $MatchedCFAResults += [PSCustomObject]@{
                PolicyName  = $CFAItem.PolicyName
                PolicyType  = $CFAItem.PolicyType
                Type        = $CFAItem.Type
                IntuneValue = $CFAItem.Value
                LocalValue  = $existsLocally.Value
                Result      = $result
                Note        = $note
            }
        }
    }

    $SameCFAReport = $MatchedCFAResults | Group-Object -Property IntuneValue | ForEach-Object {
        $group = $_.Group
        $conflictingResults = ($group | Select-Object -Property Result -Unique).Count -gt 1
        $group | ForEach-Object {
            $result = if ($conflictingResults) { "Conflict" } else { "Duplicate" }
            [PSCustomObject]@{
                PolicyName  = $_.PolicyName
                PolicyType  = $_.PolicyType
                Type        = $_.Type
                IntuneValue = $_.IntuneValue
                LocalValue  = $_.LocalValue
                Result      = $result
                Note        = $_.Note
            }
        }
    }
    return @{
        CFAStatusReport = $MatchedCFAResults | Sort-Object Type, IntuneValue
        SameCFAReport   = $SameCFAReport
    }
}
 
Function Get-IntuneDeviceData {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DeviceName
    )
    #Retrieve all properties
    $Properties = @('AadRegistered', 'hardwareInformation', 'ActivationLockBypassCode', 'AndroidSecurityPatchLevel', 'AndroidSecurityPatchLevel', 'AssignmentFilterEvaluationStatusDetails', 'AutopilotEnrolled', 'AzureActiveDirectoryDeviceId', 'AzureAdDeviceId', 'AzureAdRegistered', 'BootstrapTokenEscrowed', 'ChassisType', 'ChromeOSDeviceInfo', 'ComplianceGracePeriodExpirationDateTime', 'ComplianceState', 'ConfigurationManagerClientEnabledFeatures', 'ConfigurationManagerClientHealthState', 'ConfigurationManagerClientInformation', 'DetectedApps', 'DeviceActionResults', 'DeviceCategory', 'DeviceCategoryDisplayName', 'DeviceCompliancePolicyStates', 'DeviceConfigurationStates', 'DeviceEnrollmentType', 'DeviceFirmwareConfigurationInterfaceManaged', 'DeviceHealthAttestationState', 'DeviceName', 'DeviceRegistrationState', 'DeviceType', 'EasActivated', 'EasActivationDateTime', 'EasDeviceId', 'EmailAddress', 'EnrolledDateTime', 'EnrollmentProfileName', 'EthernetMacAddress', 'ExchangeAccessState', 'ExchangeAccessStateReason', 'ExchangeLastSuccessfulSyncDateTime', 'FreeStorageSpaceInBytes', 'Iccid', 'Id', 'Imei', 'IsEncrypted', 'IsSupervised', 'JailBroken', 'JoinType', 'LastSyncDateTime', 'LogCollectionRequests', 'LostModeState', 'ManagedDeviceMobileAppConfigurationStates', 'ManagedDeviceName', 'ManagedDeviceOwnerType', 'ManagementAgent', 'ManagementCertificateExpirationDate', 'ManagementFeatures', 'ManagementState', 'Manufacturer', 'Meid', 'Model', 'Notes', 'OSVersion', 'OperatingSystem', 'OwnerType', 'PartnerReportedThreatState', 'PhoneNumber', 'PhysicalMemoryInBytes', 'PreferMdmOverGroupPolicyAppliedDateTime', 'ProcessorArchitecture', 'RemoteAssistanceSessionErrorDetails', 'RemoteAssistanceSessionUrl', 'RequireUserEnrollmentApproval', 'RetireAfterDateTime', 'RoleScopeTagIds', 'SecurityBaselineStates', 'SerialNumber', 'SkuFamily', 'SkuNumber', 'SpecificationVersion', 'SubscriberCarrier', 'TotalStorageSpaceInBytes', 'Udid', 'UserDisplayName', 'UserId', 'UserPrincipalName', 'Users', 'UsersLoggedOn', 'WiFiMacAddress', 'WindowsActiveMalwareCount', 'WindowsProtectionState', 'WindowsRemediatedMalwareCount')

    # Get all Windows Devices from Microsoft Intune
    $DeviceID = (Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$DeviceName'").Id
    if ($DeviceID) {
        $DeviceData = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$DeviceID')?`$select=$($Properties -join ',')"
        if ($DeviceData) {

            if (-not $DeviceData) {
                Write-Host "Device not found in Intune." -ForegroundColor Red
                return $null
            }

            # Create device properties object more efficiently
            $DeviceProperties = [PSCustomObject]@{}
            foreach ($Property in $Properties) {
                if ($null -ne $DeviceData.$Property) {
                    $DeviceProperties | Add-Member -MemberType NoteProperty -Name $Property -Value $DeviceData.$Property
                }
            }

            # Return the device properties
            return $DeviceProperties
        }
        else {
            Write-Host "Device not found in Intune." -ForegroundColor Red
            return $null
        }
    }
    else {
        Write-Host "Device not found in Intune." -ForegroundColor Red
        return $null
    }
}

function Test-IntuneFilter {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilterRule,
        
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$DeviceProperties
    )

    # Helper function to evaluate a single condition
    function Evaluate-Condition {
        param (
            [string]$PropertyPath,
            [string]$Operator,
            [string]$Value
        )

        # Get the property from the device object
        $property = $PropertyPath.Trim()
        
        # Handle nested properties (e.g., device.enrollmentProfileName)
        if ($property.StartsWith("device.")) {
            $property = $property.Substring(7) # Remove "device." prefix
        }
        
        # Get the actual property value
        $actualValue = $null
        if ($DeviceProperties.PSObject.Properties.Name -contains $property) {
            $actualValue = $DeviceProperties.$property
        }
        else {
            Write-Verbose "Property '$property' not found in device properties"
            return $false
        }
        
        # Handle null values
        if ($null -eq $actualValue) {
            Write-Verbose "Property '$property' is null"
            return $false
        }
        
        # Evaluate based on operator
        switch -Regex ($Operator.Trim()) {
            "-eq" { return $actualValue -eq $Value }
            "-ne" { return $actualValue -ne $Value }
            "-contains" { return $actualValue -contains $Value }
            "-notContains" { return $actualValue -notContains $Value }
            "-startsWith" { return $actualValue.StartsWith($Value) }
            "-notStartsWith" { return -not $actualValue.StartsWith($Value) }
            "-endsWith" { return $actualValue.EndsWith($Value) }
            "-notEndsWith" { return -not $actualValue.EndsWith($Value) }
            "-match" { return $actualValue -match $Value }
            "-notMatch" { return $actualValue -notMatch $Value }
            "-in" { 
                $valueArray = $Value -split ','
                return $valueArray -contains $actualValue 
            }
            "-notIn" { 
                $valueArray = $Value -split ','
                return $valueArray -notContains $actualValue 
            }
            default {
                Write-Warning "Unsupported operator: $Operator"
                return $false
            }
        }
    }

    # Split the rule into individual conditions
    $filterRule = $FilterRule -replace '\s+', ' ' # Normalize whitespace
    
    # Initial parsing to separate by "or" and "and" operators
    $orConditions = @()
    $sections = $filterRule -split ' or '
    
    foreach ($section in $sections) {
        $andConditions = @()
        $andSections = $section -split ' and '
        
        foreach ($andSection in $andSections) {
            # Extract the condition components using a simpler approach to avoid regex issues
            # Remove outer parentheses if they exist
            $cleanSection = $andSection.Trim()
            if ($cleanSection.StartsWith("(") -and $cleanSection.EndsWith(")")) {
                $cleanSection = $cleanSection.Substring(1, $cleanSection.Length - 2).Trim()
            }
            
            # Split by spaces to get the parts
            $parts = $cleanSection -split '\s+', 3
            
            if ($parts.Count -ge 3) {
                $propertyPath = $parts[0]
                $operator = $parts[1]
                # Remove any surrounding quotes from the value
                $value = $parts[2] -replace '^["\'']|["\'']$', ''
                
                # Store the condition for evaluation
                $andConditions += @{
                    PropertyPath = $propertyPath
                    Operator     = $operator
                    Value        = $value
                }
            }
            else {
                Write-Warning "Could not parse condition: $andSection"
            }
        }
        
        $orConditions += @{ AndConditions = $andConditions }
    }
    
    # Evaluate the conditions
    foreach ($orCondition in $orConditions) {
        $allAndConditionsTrue = $true
        
        foreach ($andCondition in $orCondition.AndConditions) {
            $result = Evaluate-Condition -PropertyPath $andCondition.PropertyPath -Operator $andCondition.Operator -Value $andCondition.Value
            Write-Verbose "Evaluated: $($andCondition.PropertyPath) $($andCondition.Operator) '$($andCondition.Value)' = $result"
            
            if (-not $result) {
                $allAndConditionsTrue = $false
                break
            }
        }
        
        if ($allAndConditionsTrue) {
            return $true
        }
    }
    
    return $false
}

function Test-DevicePolicyAssignment {
    [CmdletBinding()]
    param (
        # [Parameter(Mandatory = $true)]
        # [string]$DeviceName,
        
        [Parameter(Mandatory = $true)]
        [string]$PolicyId,
        
        [Parameter(Mandatory = $false)]
        [switch]$ShowVerbose
    )
    
    # # Get device information
    if ($ShowVerbose) {
        Write-Host "Retrieving device information for $DeviceName..." -ForegroundColor Cyan
    }
    
    $device = Get-MgDeviceManagementManagedDevice -Filter "deviceName eq '$DeviceName'" 
    
    if (-not $device) {
        Write-Host "Device not found in Intune." -ForegroundColor Red
        return $false
    }
    
    $deviceId = $device.Id
    if ($ShowVerbose) {
        Write-Host "Found device with ID: $deviceId" -ForegroundColor Green
    }
    
    # Get basic device properties needed for filter evaluation
    # $deviceProperties = Invoke-MgGraphRequest -Method GET -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices('$deviceId')"
    $deviceProperties = Get-IntuneDeviceData -DeviceName $device.DeviceName
    
    # Get user's group memberships if needed for group-based assignments
    $userPrincipalName = $deviceProperties.UserPrincipalName
    $userGroupIds = @()
    
    if ($userPrincipalName) {
        if ($ShowVerbose) {
            Write-Host "Retrieving group memberships for user: $userPrincipalName..." -ForegroundColor Cyan
        }
        
        try {
            $user = Get-MgUser -UserId $userPrincipalName
            if ($user) {
                $userGroups = Get-MgUserMemberOf -UserId $user.Id
                $userGroupIds = $userGroups.id
                #$userGroupIds = $userGroups.AdditionalProperties | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' } | ForEach-Object { $_.Id }
                
                if ($ShowVerbose) {
                    Write-Host "User is a member of $($userGroupIds.Count) groups" -ForegroundColor Green
                }
            }
        }
        catch {
            Write-Host "Error retrieving user group memberships: $_" -ForegroundColor Yellow
        }
    }
    
    # Get Azure AD device group memberships
    $deviceGroupIds = @()
    
    if ($deviceProperties.AzureAdDeviceId) {
        if ($ShowVerbose) {
            Write-Host "Retrieving group memberships for Azure AD device..." -ForegroundColor Cyan
        }
        
        try {
            # Get the Azure AD device
            $azureAdDevice = Get-MgDevice -Filter "DeviceId eq '$($deviceProperties.AzureAdDeviceId)'"
            
            if ($azureAdDevice) {
                # Get device group memberships
                $deviceGroups = Get-MgDeviceMemberOf -DeviceId $azureAdDevice.Id
                $deviceGroupIds = $deviceGroups.id
                # $deviceGroupIds = $deviceGroups.AdditionalProperties | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' } | ForEach-Object { $_.Id }
                
                if ($ShowVerbose) {
                    Write-Host "Device is a member of $($deviceGroupIds.Count) groups" -ForegroundColor Green
                }
            }
            else {
                Write-Host "Azure AD device not found for device ID: $($deviceProperties.AzureAdDeviceId)" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "Error retrieving device group memberships: $_" -ForegroundColor Yellow
        }
    }
    
    # Get all Intune filters
    if ($ShowVerbose) {
        Write-Host "Retrieving all Intune filters..." -ForegroundColor Cyan
    }
    
    $intuneFilters = Get-MgBetaDeviceManagementAssignmentFilter | Where-Object { $_.Platform -eq "windows10AndLater" }
    
    # Get policy assignments
    if ($ShowVerbose) {
        Write-Host "Getting assignments for policy ID: $PolicyId" -ForegroundColor Blue
    }
    
    $assignmentsUri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies('$PolicyId')/assignments"
    $assignmentResponse = Invoke-MgGraphRequest -Method GET -Uri $assignmentsUri
    
    $isAssigned = $false
    
    # Check each assignment to see if it applies to this device
    foreach ($assignment in $assignmentResponse.value) {
        $targetType = $assignment.target.'@odata.type'
        $filterId = $assignment.target.deviceAndAppManagementAssignmentFilterId
        $filterType = $assignment.target.deviceAndAppManagementAssignmentFilterType
        
        # Check if base assignment applies (without filter)
        $baseApplicable = $false
        
        switch ($targetType) {
            "#microsoft.graph.allDevicesAssignmentTarget" {
                $baseApplicable = $true
                if ($ShowVerbose) {
                    Write-Host "  Assignment targets all devices" -ForegroundColor Gray
                }
            }
            "#microsoft.graph.allLicensedUsersAssignmentTarget" {
                $baseApplicable = ($null -ne $userPrincipalName)
                if ($ShowVerbose) {
                    Write-Host "  Assignment targets all licensed users" -ForegroundColor Gray
                }
            }
            "#microsoft.graph.groupAssignmentTarget" {
                $groupId = $assignment.target.groupId
                # Check if device or user is a member of this group
                $baseApplicable = ($userGroupIds -contains $groupId) -or ($deviceGroupIds -contains $groupId)
                if ($ShowVerbose) {
                    Write-Host "  Assignment targets group ID: $groupId (Device/User in group: $baseApplicable)" -ForegroundColor Gray
                }
            }
        }
        
        # Final assignment result after applying filter (if any)
        $assignmentApplies = $baseApplicable
        
        # Handle filter logic if present
        if ($filterId) {
            $filter = $intuneFilters | Where-Object { $_.id -eq $filterId }
            
            if ($filter) {
                if ($ShowVerbose) {
                    Write-Host "  Evaluating filter: $($filter.displayName)" -ForegroundColor Gray
                }
                
                $filterMatched = Test-IntuneFilter -FilterRule $filter.rule -DeviceProperties $deviceProperties
    
                if ($ShowVerbose) {
                    Write-Host "  Filter match result: $filterMatched" -ForegroundColor $(if ($filterMatched) { "Green" } else { "Yellow" })
                }
                
                # Apply filter logic based on include/exclude type
                if ($filterType -eq "include") {
                    $assignmentApplies = $baseApplicable -and $filterMatched
                }
                elseif ($filterType -eq "exclude") {
                    $assignmentApplies = $baseApplicable -and (-not $filterMatched)
                }
            }
            else {
                # Filter not found - consider as not matching
                $assignmentApplies = $false
                if ($ShowVerbose) {
                    Write-Host "  Filter not found with ID: $filterId" -ForegroundColor Red
                }
            }
        }
        
        if ($ShowVerbose) {
            Write-Host "  Assignment applies: $assignmentApplies" -ForegroundColor $(if ($assignmentApplies) { "Green" } else { "Yellow" })
        }
        
        # If any assignment applies, the policy is assigned to this device
        if ($assignmentApplies) {
            $isAssigned = $true
            # Can break here since we only need to know if at least one assignment applies
            break
        }
    }
    
    if ($ShowVerbose) {
        Write-Host "Policy $(if ($isAssigned) { "IS" } else { "IS NOT" }) assigned to device $DeviceName" -ForegroundColor $(if ($isAssigned) { "Green" } else { "Yellow" })
    }
    
    return $isAssigned
}

# Main script execution starts here
if (-not (Test-AdminElevation)) {
    Write-Host "Script requires administrative privileges to run. Exiting." -ForegroundColor Red
    return
}

# Load required modules
Install-Requirements

# Connect to Microsoft Graph
Ensure-MgGraphConnection

# Get all Configuration Policies (you can filter this as needed)
$configPolicies = Get-IntuneConfiguredASRRules

# Specify a device to check
$deviceName = $env:COMPUTERNAME
$deviceProperties = Get-IntuneDeviceData -DeviceName $deviceName

# Check which policies apply to this device
$applicablePolicies = @()

Write-Host "Checking policies for device: $deviceName" -ForegroundColor Cyan

foreach ($policy in $script:AllPolicies) {
    $policyId = $policy.id
    $policyName = $policy.name

    Write-Host "Checking policy: $policyName" -ForegroundColor Magenta

    # Check if the device is assigned this policy
    $isAssigned = Test-DevicePolicyAssignment -PolicyId $policyId

    if ($isAssigned) {
        Write-Host "[OK] Policy '$policyName' is assigned to device $deviceName" -ForegroundColor Green
        $applicablePolicies += $policy    
    } else {
        Write-Host "[X]  Policy '$policyName' is NOT assigned to device $deviceName" -ForegroundColor Red
    }
}

 try {

    if ($applicablePolicies.Count -eq 0) {
            Write-Host "No ASR rules found in Intune or incorrect connection." -ForegroundColor Yellow
            Write-Host "continuing with local ASR rule inspection..." -ForegroundColor Yellow
            $IntuneASRConfiguration = @()
    }
    
    Write-Host "Checking local ASR rule status..." -ForegroundColor Cyan
    $ASRData = Get-ASRStatus
    
    if ($ASRData.Count -eq 0) {
            Write-Host "No ASR rule data found to report." -ForegroundColor Yellow
            return
    }

    $DuplicateASRRules = Find-DuplicateASRRules
    $ASRExclusions = Get-ASRStatusExclusions
    $DuplicateASRExclusions = $ASRExclusions.SameExclusionsReport
    $ASRExclusions = $ASRExclusions.ASRExclusionsReport
    $CFAStatus = get-CFAStatus


    Write-host "Duplicates found: $($DuplicateASRRules.Count)" -ForegroundColor Yellow
    Write-host "Exclusions found: $($ASRExclusions.Count)" -ForegroundColor Yellow
    Write-Host "Generating ASR rule comparison report..." -ForegroundColor Cyan
    Write-host "Generating ASR exclusions report..." -ForegroundColor Cyan
    Write-host "Generating Controlled Folder Access report..." -ForegroundColor Cyan
    
} catch {
    Write-Host ("Error during ASR rule inspection: $($_.Exception.Message)") -ForegroundColor Red
}

New-HTMLReport -ASRRules $ASRData -DuplicateASRRules $DuplicateASRRules -ASRExclusions $ASRExclusions -DuplicateASRExclusions $DuplicateASRExclusions -CFAStatus $CFAStatus

# Disconnect from Microsoft Graph
Disconnect-MgGraph | Out-Null