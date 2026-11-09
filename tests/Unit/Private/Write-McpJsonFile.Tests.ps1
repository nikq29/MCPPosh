BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Write-McpJsonFile' {
    It 'writes JSON that can be read back' {
        InModuleScope MCPPosh -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $file = Join-Path $Home 'out/data.json'
            Write-McpJsonFile -Path $file -InputObject ([ordered]@{ list = @('one'); n = 1 })
            $data = Read-McpJsonFile -Path $file
            $data.list | Should -Be @('one')
            $data.n | Should -Be 1
        }
    }
}
