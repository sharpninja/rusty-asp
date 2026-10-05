# Compatibility entry point. Use Import-Module .\scripts\RustyAsp.psd1 for interactive use.
[CmdletBinding()]
param([ValidateRange(1024,65535)][int]$Port = 8087, [switch]$SkipBuild, [string]$DatabasePath)
Import-Module (Join-Path $PSScriptRoot 'RustyAsp.psd1') -ErrorAction Stop
Start-RustyAsp @PSBoundParameters
