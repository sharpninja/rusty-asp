$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$RuntimeRoot = Join-Path $ProjectRoot '.runtime'
$ClassId = '{2D825ABD-3CE3-4694-9EF5-9E46AD821EB0}'
$ProgId = 'RustyAsp.TaskBoard'
$ComponentPath = Join-Path $RuntimeRoot 'rusty_asp.dll'
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
