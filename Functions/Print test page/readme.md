# Out-TestPage Function README

## Overview
The `Out-TestPage` function is a PowerShell script designed to print a test page to a specified printer on a Windows system. It utilizes Windows Management Instrumentation (WMI) via CIM to interact with printer devices.

## Description
This function retrieves a list of installed printers using the `Win32_Printer` CIM class, filters for the specified printer name, and invokes the `printtestpage` method to print a test page. It provides feedback via the console about the printing action.

## Parameters
- **printername** (string): The name of the printer to which the test page should be printed. This parameter is mandatory.

## Usage
To use this function, source the script file and call it with the printer name as an argument.

### Example
```powershell
# Source the function
. .\Out-TestPage.ps1

# Print a test page to a printer named "MyPrinter"
Out-TestPage -printername "MyPrinter"
```

## Requirements
- Windows operating system with PowerShell.
- Administrative privileges may be required to access printer information and perform printing operations.
- The printer must be installed and accessible on the system.

## Notes
- Ensure the printer name matches exactly as it appears in the system (case-sensitive in some contexts).
- The function outputs a message to the console indicating the printer being used.
- If the specified printer is not found, the function may not produce an error but will not print anything.