. "$PSScriptRoot\Common.ps1"
if (![Environment]::Is64BitProcess) { throw 'Run this script in 64-bit PowerShell.' }
if (!(Test-Path -LiteralPath $ComponentPath)) { throw 'Run scripts\Build.ps1 first.' }
$classPath = "HKCU:\Software\Classes\CLSID\$ClassId"
$serverPath = "$classPath\InprocServer32"
if (Test-Path -LiteralPath $serverPath) {
    $oldPath = (Get-Item -LiteralPath $serverPath).GetValue('')
    if ($oldPath -ne $ComponentPath) { throw "This CLSID is registered to another checkout: $oldPath. Unregister that checkout first." }
}
New-Item -Path $classPath -Force | Out-Null
Set-Item -LiteralPath $classPath -Value 'Rusty ASP task board'
New-Item -Path $serverPath -Force | Out-Null
Set-Item -LiteralPath $serverPath -Value $ComponentPath
New-ItemProperty -LiteralPath $serverPath -Name ThreadingModel -Value Apartment -PropertyType String -Force | Out-Null
New-Item -Path "$classPath\ProgID" -Force | Out-Null
Set-Item -LiteralPath "$classPath\ProgID" -Value $ProgId
New-Item -Path "HKCU:\Software\Classes\$ProgId\CLSID" -Force | Out-Null
Set-Item -LiteralPath "HKCU:\Software\Classes\$ProgId\CLSID" -Value $ClassId
Write-Output "Registered $ProgId for the current user."
