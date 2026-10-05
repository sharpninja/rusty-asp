param([switch]$Test)
. "$PSScriptRoot\Common.ps1"
if (Get-RunningSite) { throw 'Stop the project server with scripts\Stop.ps1 before rebuilding the COM DLL.' }
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
