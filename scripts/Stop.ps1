. "$PSScriptRoot\Common.ps1"
$process = Get-RunningSite
if ($process) { Stop-Process -Id $process.Id; $process.WaitForExit(); Write-Output 'Stopped this project IIS Express process.' }
else { Write-Output 'This project server is not running.' }
