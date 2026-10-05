param([ValidateRange(1024,65535)][int]$Port = 8087, [switch]$SkipBuild, [string]$DatabasePath)
. "$PSScriptRoot\Common.ps1"
if (Get-RunningSite) { throw 'This project server is already running. See .runtime\server.json.' }
if (!$SkipBuild) { & "$PSScriptRoot\Build.ps1" }
& "$PSScriptRoot\Register.ps1"
$iis = Get-IisExpress
if (!$DatabasePath) { $DatabasePath = Join-Path $ProjectRoot 'data\tasks.sqlite' }
$DatabasePath = [IO.Path]::GetFullPath($DatabasePath)
New-Item -ItemType Directory -Path (Split-Path -Parent $DatabasePath) -Force | Out-Null
New-Item -ItemType Directory -Path "$RuntimeRoot\logs","$RuntimeRoot\cache" -Force | Out-Null
$template = Join-Path (Split-Path -Parent $iis) 'config\templates\PersonalWebServer\applicationhost.config'
[xml]$config = Get-Content -LiteralPath $template -Raw
$sites = $config.configuration.'system.applicationHost'.sites
@($sites.SelectNodes('site')) | ForEach-Object { [void]$sites.RemoveChild($_) }
$site = $config.CreateElement('site')
$site.SetAttribute('name','RustyAsp')
$site.SetAttribute('id','1')
$application = $config.CreateElement('application')
$application.SetAttribute('path','/')
$application.SetAttribute('applicationPool','UnmanagedClassicAppPool')
$directory = $config.CreateElement('virtualDirectory')
$directory.SetAttribute('path','/')
$directory.SetAttribute('physicalPath',(Join-Path $ProjectRoot 'site'))
[void]$application.AppendChild($directory)
[void]$site.AppendChild($application)
$bindings = $config.CreateElement('bindings')
$binding = $config.CreateElement('binding')
$binding.SetAttribute('protocol','http')
$binding.SetAttribute('bindingInformation',":${Port}:localhost")
[void]$bindings.AppendChild($binding)
[void]$site.AppendChild($bindings)
[void]$sites.PrependChild($site)
$config.configuration.'system.webServer'.asp.SetAttribute('scriptErrorSentToBrowser','false')
$config.configuration.'system.webServer'.asp.cache.SetAttribute('diskTemplateCacheDirectory',"$RuntimeRoot\cache")
$config.configuration.'system.webServer'.security.authentication.anonymousAuthentication.SetAttribute('userName','')
$sites.siteDefaults.logFile.SetAttribute('directory',"$RuntimeRoot\logs")
$configPath = Join-Path $RuntimeRoot 'applicationhost.config'
$config.Save($configPath)
$oldDatabase = $env:RUSTY_ASP_DATABASE
try {
    $env:RUSTY_ASP_DATABASE = $DatabasePath
    $process = Start-Process -FilePath $iis -ArgumentList @("/config:`"$configPath`"",'/site:RustyAsp','/systray:false') -WindowStyle Hidden -PassThru -RedirectStandardOutput "$RuntimeRoot\stdout.log" -RedirectStandardError "$RuntimeRoot\stderr.log"
} finally { $env:RUSTY_ASP_DATABASE = $oldDatabase }
$process.Refresh()
@{ ProcessId=$process.Id; StartTicks=$process.StartTime.ToUniversalTime().Ticks.ToString(); Port=$Port; Database=$DatabasePath } | ConvertTo-Json | Set-Content -LiteralPath "$RuntimeRoot\server.json" -Encoding UTF8
$ready = $false
for ($attempt=0; $attempt -lt 30; $attempt++) {
    if ($process.HasExited) { break }
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:$Port/health.asp" -UseBasicParsing -TimeoutSec 2
        if ($response.StatusCode -eq 200 -and $response.Content -match 'Rusty ASP') { $ready = $true; break }
    } catch { Start-Sleep -Milliseconds 200 }
}
if (!$ready) { throw "The server failed its health check. Inspect $RuntimeRoot\stdout.log and stderr.log; stop it with scripts\Stop.ps1." }
Write-Output "Rusty ASP is running at http://localhost:$Port/"
