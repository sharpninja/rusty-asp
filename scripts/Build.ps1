# Compatibility entry point. Use Import-Module .\scripts\RustyAsp.psd1 for interactive use.
[CmdletBinding()]
param([switch]$Test)
Import-Module (Join-Path $PSScriptRoot 'RustyAsp.psd1') -ErrorAction Stop
Invoke-RustyAspBuild @PSBoundParameters
