BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Test-McpLooksLikePath' {
    It 'treats rooted and relative paths as paths' -ForEach @('/data/kb', 'C:\kb', './kb', 'share/kb', 'a\b') {
        InModuleScope MCPPosh -Parameters @{ Value = $_ } { param($Value) Test-McpLooksLikePath -Value $Value | Should -BeTrue }
    }

    It 'treats plain names as names' {
        InModuleScope MCPPosh { Test-McpLooksLikePath -Value 'Contoso' | Should -BeFalse }
    }
}
