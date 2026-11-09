BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Assert-McpAzStorageModule' {
    It 'does nothing when the Az.Storage cmdlets are available' {
        InModuleScope MCPPosh {
            Mock Get-Command { [pscustomobject]@{ Name = 'Set-AzStorageFileContent' } } -ParameterFilter { $Name -eq 'Set-AzStorageFileContent' }
            { Assert-McpAzStorageModule } | Should -Not -Throw
        }
    }

    It 'explains how to install Az.Storage when it is missing' {
        InModuleScope MCPPosh {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Set-AzStorageFileContent' }
            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'Az.Storage' }
            { Assert-McpAzStorageModule } | Should -Throw '*Install-Module Az.Storage*'
        }
    }
}
