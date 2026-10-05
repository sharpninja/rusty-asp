. "$PSScriptRoot\Common.ps1"
if (Get-RunningSite) { throw 'Stop the server before removing its COM registration.' }
$classPath = "HKCU:\Software\Classes\CLSID\$ClassId"
if (Test-Path -LiteralPath "$classPath\InprocServer32") {
    if ((Get-Item -LiteralPath "$classPath\InprocServer32").GetValue('') -ne $ComponentPath) {
        throw 'This registration belongs to another checkout. Refusing to remove it.'
    }
    Remove-Item -LiteralPath $classPath -Recurse
    $progPath = "HKCU:\Software\Classes\$ProgId"
    if ((Get-Item -LiteralPath "$progPath\CLSID").GetValue('') -eq $ClassId) { Remove-Item -LiteralPath $progPath -Recurse }
}
Write-Output 'Removed this project COM registration. Source and task data are preserved.'
