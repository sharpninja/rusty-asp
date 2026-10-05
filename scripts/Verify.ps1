param([int]$Port = 8088)
. "$PSScriptRoot\Common.ps1"
if (Get-RunningSite) { throw 'Stop the running project server before verification.' }
$database = Join-Path $RuntimeRoot ('verification-' + [guid]::NewGuid().ToString('N') + '.sqlite')
$url = "http://localhost:$Port/default.asp"
$script:checks = 0
function Assert-That([bool]$Condition,[string]$Message) {
    if (!$Condition) { throw "FAILED: $Message" }
    $script:checks++
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
        $reader = New-Object IO.StreamReader($response.GetResponseStream())
        try { $text = $reader.ReadToEnd() } finally { $reader.Dispose() }
        return [pscustomobject]@{StatusCode=[int]$response.StatusCode;Content=$text}
    }
}
try {
    & "$PSScriptRoot\Start.ps1" -Port $Port -SkipBuild -DatabasePath $database
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
    & "$PSScriptRoot\Stop.ps1"
    & "$PSScriptRoot\Start.ps1" -Port $Port -SkipBuild -DatabasePath $database
    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    $page = Get-Page
    Assert-That ($page.Content.Contains('A persistent Rust task')) 'Data survives an actual IIS Express restart'
    $csrf = Token $page.Content
    $page = Post-Form @{action='delete';id=$id;csrf=$csrf}
    Assert-That (!$page.Content.Contains('data-task-id="'+$id+'"')) 'Delete removes the persisted task'
    $page = Get-Page
    Assert-That (!$page.Content.Contains('FORGED')) 'Rejected request made no database change'
    Write-Output "$script:checks HTTP integration checks passed. Test database: $database"
} finally {
    & "$PSScriptRoot\Stop.ps1"
}
