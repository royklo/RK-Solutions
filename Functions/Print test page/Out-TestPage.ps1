Function out-TestPage
{
Param(
  [string]$printername
  )

  $Printers = Get-CimInstance -ClassName Win32_Printer
  $Printer = $Printers | Where-Object Name -eq "$printername"
 Invoke-CimMethod -MethodName printtestpage -InputObject ($printer)
 Write-Host "Printing to $($printer).Name"
}