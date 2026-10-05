#Requires -Version 5.1
# Importing this module defines commands; it does not build, register, or start a server.
$ErrorActionPreference = 'Stop'
$script:ProjectRoot = Split-Path -Parent $PSScriptRoot
$script:RuntimeRoot = Join-Path $ProjectRoot '.runtime'
$script:ClassId = '{2D825ABD-3CE3-4694-9EF5-9E46AD821EB0}'
$script:ProgId = 'RustyAsp.TaskBoard'
$script:ComponentPath = Join-Path $RuntimeRoot 'rusty_asp.dll'
function Get-Cargo {
    $command = Get-Command cargo -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $candidate = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.cargo\bin\cargo.exe'
    if (Test-Path -LiteralPath $candidate) { return $candidate }
    throw 'Install Rust stable x64 MSVC from https://rustup.rs, plus Visual Studio C++ build tools.'
}
function Get-TargetDirectory {
    if ($env:CARGO_TARGET_DIR) { return [IO.Path]::GetFullPath($env:CARGO_TARGET_DIR) }
    return Join-Path $ProjectRoot '.build'
}
function Get-IisExpress {
    $candidate = Join-Path $env:ProgramFiles 'IIS Express\iisexpress.exe'
    if (!(Test-Path -LiteralPath $candidate)) { throw 'Install Microsoft IIS Express x64 before starting this project.' }
    return $candidate
}
function Get-RunningSite {
    $statePath = Join-Path $RuntimeRoot 'server.json'
    if (!(Test-Path -LiteralPath $statePath)) { return $null }
    $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    $process = Get-Process -Id $state.ProcessId -ErrorAction SilentlyContinue
    if (!$process) { return $null }
    if ($process.ProcessName -ne 'iisexpress' -or $process.StartTime.ToUniversalTime().Ticks.ToString() -ne $state.StartTicks) {
        throw 'The recorded process is not this project server. Refusing to touch it.'
    }
    return $process
}

function Invoke-RustyAspBuild {
    <#
    .SYNOPSIS
    Build the native Rust COM component, optionally running Rust tests.
    .EXAMPLE
    Invoke-RustyAspBuild -Test
    #>
    [CmdletBinding()]
    param([switch]$Test)
    if (Get-RunningSite) { throw 'Stop the project server with Stop-RustyAsp before rebuilding the COM DLL.' }
    $cargo = Get-Cargo
    $target = Get-TargetDirectory
    if ($Test) {
        & $cargo test --locked --manifest-path "$ProjectRoot\Cargo.toml" --target-dir $target
        if ($LASTEXITCODE -ne 0) { throw 'Rust tests failed.' }
    }
    & $cargo build --release --locked --manifest-path "$ProjectRoot\Cargo.toml" --target-dir $target
    if ($LASTEXITCODE -ne 0) { throw 'Rust build failed.' }
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $target 'release\rusty_asp.dll') -Destination $ComponentPath -Force
    Write-Output "Built $ComponentPath"
}

function Register-RustyAsp {
    <#
    .SYNOPSIS
    Register this checkout's COM component for the current Windows user.
    .EXAMPLE
    Register-RustyAsp
    #>
    [CmdletBinding()]
    param()
    if (![Environment]::Is64BitProcess) { throw 'Run this script in 64-bit PowerShell.' }
    if (!(Test-Path -LiteralPath $ComponentPath)) { throw 'Run Invoke-RustyAspBuild first.' }
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
}

function Start-RustyAsp {
    <#
    .SYNOPSIS
    Build and start the local IIS Express task board.
    .EXAMPLE
    Start-RustyAsp -SkipBuild
    #>
    [CmdletBinding()]
    param([ValidateRange(1024,65535)][int]$Port = 8087, [switch]$SkipBuild, [string]$DatabasePath)
    if (Get-RunningSite) { throw 'This project server is already running. See .runtime\server.json.' }
    if (!$SkipBuild) { Invoke-RustyAspBuild }
    Register-RustyAsp
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
    if (!$ready) { throw "The server failed its health check. Inspect $RuntimeRoot\stdout.log and stderr.log; stop it with Stop-RustyAsp." }
    Write-Output "Rusty ASP is running at http://localhost:$Port/"
}

function Stop-RustyAsp {
    <#
    .SYNOPSIS
    Stop only the IIS Express process recorded for this checkout.
    .EXAMPLE
    Stop-RustyAsp
    #>
    [CmdletBinding()]
    param()
    $process = Get-RunningSite
    if ($process) { Stop-Process -Id $process.Id; $process.WaitForExit(); Write-Output 'Stopped this project IIS Express process.' }
    else { Write-Output 'This project server is not running.' }
}

function Unregister-RustyAsp {
    <#
    .SYNOPSIS
    Remove this checkout's COM registration while preserving task data.
    .EXAMPLE
    Unregister-RustyAsp
    #>
    [CmdletBinding()]
    param()
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
}

function Initialize-RustyAspData {
    <#
    .SYNOPSIS
    Add three demonstration tasks only when the board is empty.
    .EXAMPLE
    Initialize-RustyAspData
    #>
    [CmdletBinding()]
    param([ValidateRange(1024,65535)][int]$Port = 8087)
    $ErrorActionPreference='Stop'
    $url="http://localhost:$Port/default.asp"
    $page=Invoke-WebRequest -UseBasicParsing -Uri $url -SessionVariable demoSession
    if ($page.Content -match 'data-task-id=') { Write-Output 'Board already has tasks; no sample data added.'; return }
    $token=[regex]::Match($page.Content,'name="csrf" value="([^"]+)"').Groups[1].Value
    foreach ($title in @('Prove Rust objects render in Classic ASP','Write the follow-up article','Make this starter your own')) {
        $page=Invoke-WebRequest -UseBasicParsing -Uri $url -WebSession $demoSession -Method Post -Body @{csrf=$token;action='add';title=$title}
    }
    $ids=[regex]::Matches($page.Content,'data-task-id="([0-9]+)"')
    $firstId=$ids[$ids.Count-1].Groups[1].Value
    $null=Invoke-WebRequest -UseBasicParsing -Uri $url -WebSession $demoSession -Method Post -Body @{csrf=$token;action='setdone';id=$firstId;done='1'}
    Write-Output 'Added three sample tasks to the empty board.'
}

function Test-RustyAsp {
    <#
    .SYNOPSIS
    Run the HTTP integration suite against an isolated test database.
    .EXAMPLE
    Test-RustyAsp
    #>
    [CmdletBinding()]
    param([ValidateRange(1024,65535)][int]$Port = 8088)
    if (Get-RunningSite) { throw 'Stop the running project server before verification.' }
    $database = Join-Path $RuntimeRoot ('verification-' + [guid]::NewGuid().ToString('N') + '.sqlite')
    $url = "http://localhost:$Port/default.asp"
    $result = [pscustomobject]@{ Passed = 0; Database = $database; Port = $Port }
    function Assert-That([bool]$Condition,[string]$Message) {
        if (!$Condition) { throw "FAILED: $Message" }
        $result.Passed++
        Write-Output "PASS: $Message"
    }
    function Get-Page([string]$Suffix='') { Invoke-WebRequest -UseBasicParsing -Uri ($url+$Suffix) -WebSession $session -TimeoutSec 10 }
    function Token([string]$Html) { [regex]::Match($Html,'name="csrf" value="([^"]+)"').Groups[1].Value }
    function Post-Form([hashtable]$Fields,[string]$Suffix='') {
        $body = ($Fields.GetEnumerator() | ForEach-Object { [uri]::EscapeDataString($_.Key) + '=' + [uri]::EscapeDataString([string]$_.Value) }) -join '&'
        try { return Invoke-WebRequest -UseBasicParsing -Uri ($url+$Suffix) -Method Post -Body $body -ContentType 'application/x-www-form-urlencoded; charset=utf-8' -WebSession $session -TimeoutSec 10 }
        catch {
            if (!$_.Exception.Response) { throw }
            $response = $_.Exception.Response
            if ($response -is [Net.HttpWebResponse]) {
                $reader = New-Object IO.StreamReader($response.GetResponseStream())
                try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
            } else { $text = $_.ErrorDetails.Message }
            return [pscustomobject]@{StatusCode=[int]$response.StatusCode;Content=$text}
        }
    }
    try {
        Start-RustyAsp -Port $Port -SkipBuild -DatabasePath $database
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $page = Get-Page
        Assert-That ($page.StatusCode -eq 200) 'ASP page is served by IIS Express'
        $csrf = Token $page.Content
        Assert-That ($csrf.Length -eq 36) 'Rust generates a session form token'
        $other = Invoke-WebRequest -UseBasicParsing -Uri $url
        Assert-That ((Token $other.Content) -ne $csrf) 'Different sessions receive different tokens'
        $bad = Post-Form @{action='add';title='FORGED';csrf='invalid'}
        Assert-That ($bad.StatusCode -eq 403) 'Forged form token is rejected'
        $bad = Post-Form @{action='add';title=' ';csrf=$csrf}
        Assert-That ($bad.StatusCode -eq 400) 'Rust validation rejects blank titles'
        $bad = Post-Form @{action='add';title=('x'*201);csrf=$csrf}
        Assert-That ($bad.StatusCode -eq 400) 'Server rejects overlong titles without relying on browser limits'
        $bad = Post-Form @{action='add';title='INVALID FILTER MUTATION';csrf=$csrf} '?show=invalid'
        Assert-That ($bad.StatusCode -eq 400 -and !((Get-Page).Content.Contains('INVALID FILTER MUTATION'))) 'Invalid filter is rejected before a POST can change data'
        $title = '<script>alert("x")</script> O''Brien ' + [char]0x03A9
        $page = Post-Form @{action='add';title=$title;csrf=$csrf}
        Assert-That ($page.StatusCode -eq 200) 'Task creation redirects to a rendered page'
        Assert-That ($page.Content.Contains('&lt;script&gt;') -and !$page.Content.Contains('<script>alert')) 'Stored HTML is encoded in the template'
        Assert-That ([Net.WebUtility]::HtmlDecode($page.Content).Contains([string][char]0x03A9)) 'Unicode survives HTTP, COM, SQLite, and HTML'
        $id = [regex]::Match($page.Content,'data-task-id="([0-9]+)"').Groups[1].Value
        Assert-That ($id -ne '') 'Rust returns a task data object with an ID'
        $page = Post-Form @{action='rename';id=$id;title='A persistent Rust task';csrf=$csrf}
        Assert-That ($page.Content.Contains('A persistent Rust task')) 'Rename traverses the COM boundary with two correctly ordered arguments'
        $page = Post-Form @{action='setdone';id=$id;done='1';csrf=$csrf}
        Assert-That ($page.Content -match 'class="task is-done"') 'Complete a task'
        Assert-That (!((Get-Page '?show=open').Content.Contains('data-task-id="'+$id+'"'))) 'Open filter excludes completed tasks'
        Assert-That ((Get-Page '?show=done').Content.Contains('data-task-id="'+$id+'"')) 'Done filter includes completed tasks'
        $page = Post-Form @{action='setdone';id=$id;done='0';csrf=$csrf}
        Assert-That ($page.Content -notmatch 'class="task is-done"') 'Reopen a task'
        $bad = Post-Form @{action='delete';id='1.2';csrf=$csrf}
        Assert-That ($bad.StatusCode -eq 400) 'Malformed IDs are rejected'
        Stop-RustyAsp
        Start-RustyAsp -Port $Port -SkipBuild -DatabasePath $database
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $page = Get-Page
        Assert-That ($page.Content.Contains('A persistent Rust task')) 'Data survives an actual IIS Express restart'
        $csrf = Token $page.Content
        $page = Post-Form @{action='delete';id=$id;csrf=$csrf}
        Assert-That (!$page.Content.Contains('data-task-id="'+$id+'"')) 'Delete removes the persisted task'
        $page = Get-Page
        Assert-That (!$page.Content.Contains('FORGED')) 'Rejected request made no database change'
        Write-Output "$($result.Passed) HTTP integration checks passed. Test database: $database"
        $result
    } finally {
        Stop-RustyAsp
    }
}

function Get-RustyAspStatus {
    <#
    .SYNOPSIS
    Return the running state, URL, database, and paths for this checkout.
    .EXAMPLE
    Get-RustyAspStatus
    #>
    [CmdletBinding()]
    param()
    $process = Get-RunningSite
    $state = $null
    if ($process) { $state = Get-Content -LiteralPath (Join-Path $RuntimeRoot 'server.json') -Raw | ConvertFrom-Json }
    [pscustomobject]@{
        Running = [bool]$process
        ProcessId = if ($process) { $process.Id } else { $null }
        Url = if ($state) { "http://localhost:$($state.Port)/" } else { $null }
        DatabasePath = if ($state) { $state.Database } else { $null }
        ProjectRoot = $ProjectRoot
        ComponentPath = $ComponentPath
    }
}

Export-ModuleMember -Function Invoke-RustyAspBuild, Register-RustyAsp, Start-RustyAsp, Stop-RustyAsp, Unregister-RustyAsp, Initialize-RustyAspData, Test-RustyAsp, Get-RustyAspStatus
