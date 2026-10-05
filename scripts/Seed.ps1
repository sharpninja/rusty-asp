param([int]$Port = 8087)
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
