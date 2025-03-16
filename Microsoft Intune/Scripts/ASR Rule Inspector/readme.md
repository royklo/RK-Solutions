# ASR Rule Inspector

## Overview

The ASR Rule Inspector is a PowerShell script designed to inspect and report on the status of Attack Surface Reduction (ASR) rules, ASR exclusions, and Controlled Folder Access (CFA) settings on a Windows device.

## Functions

### Test-AdminElevation
Checks if the script is running with elevated permissions.

### Get-ASRStatus
Retrieves the status of ASR rules configured on the device.

### Get-ASRStatusExclusions
Finds and lists all ASR exclusions configured on the device.

### get-CFAStatus
Retrieves the status of Controlled Folder Access and lists protected folders and applications.

## Usage

1. Ensure you run the script with administrative privileges.
2. Execute the script in PowerShell.

## Output

- **ASR Rules Status**: Displays the status of each ASR rule.
- **ASR Exclusions**: Lists any ASR exclusions found.
- **Controlled Folder Access**: Shows the status of CFA and lists protected folders and applications.

## Example

```powershell
.\ASRRuleInspector.ps1
```

## Notes

- The script requires access to the Windows registry to retrieve ASR and CFA settings.
- Ensure PowerShell is running with the necessary permissions to access the registry.

## License

This project is licensed under the MIT License.