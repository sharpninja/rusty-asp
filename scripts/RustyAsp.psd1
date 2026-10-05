@{
    RootModule = 'RustyAsp.psm1'
    ModuleVersion = '0.2.0'
    GUID = 'b97c7ab5-4816-4fc6-a1d8-09585f853508'
    Author = 'Sharp Ninja'
    Description = 'Build, run, and verify the Rusty ASP Classic ASP + Rust COM starter on Windows x64.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Invoke-RustyAspBuild', 'Register-RustyAsp', 'Start-RustyAsp', 'Stop-RustyAsp',
        'Unregister-RustyAsp', 'Initialize-RustyAspData', 'Test-RustyAsp', 'Get-RustyAspStatus'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            Tags = @('Rust', 'ClassicASP', 'IISExpress', 'COM')
            ProjectUri = 'https://github.com/sharpninja/rusty-asp'
        }
    }
}
