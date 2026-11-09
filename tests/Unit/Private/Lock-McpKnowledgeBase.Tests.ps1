BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Lock-McpKnowledgeBase' {
    It 'returns an exclusive lock that blocks a second lock until it is released' {
        InModuleScope MCPPosh -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $first = Lock-McpKnowledgeBase -KbPath $Home
            try {
                $first | Should -BeOfType [System.IO.FileStream]
                { Lock-McpKnowledgeBase -KbPath $Home -TimeoutSeconds 1 } | Should -Throw '*Timed out*'
            }
            finally {
                $first.Dispose()
            }
            $second = Lock-McpKnowledgeBase -KbPath $Home -TimeoutSeconds 1
            $second.Dispose()
        }
    }
}
