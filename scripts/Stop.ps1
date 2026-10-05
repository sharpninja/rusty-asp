# Compatibility entry point. Use Import-Module .\scripts\RustyAsp.psd1 for interactive use.
[CmdletBinding()]
param()
Import-Module (Join-Path $PSScriptRoot 'RustyAsp.psd1') -ErrorAction Stop
Stop-RustyAsp @PSBoundParameters
