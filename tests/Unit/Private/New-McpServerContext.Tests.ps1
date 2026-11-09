BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'New-McpServerContext' {
    It 'creates a context with default log paths' {
        InModuleScope MCPPosh {
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Ctx -CreateIfMissing
            $stdio = New-McpServerContext -KnowledgeBase $kb
            $stdio.Transport | Should -Be 'Stdio'
            $stdio.LogPath | Should -BeLike '*server-stdio.log'
            $stdio.AllowWrite | Should -BeFalse
            $http = New-McpServerContext -KnowledgeBase $kb -Transport Http -AllowWrite -EchoLog
            $http.LogPath | Should -BeLike '*server-http.log'
            $http.AllowWrite | Should -BeTrue
            $http.EchoLog | Should -BeTrue
            $http.ProtocolVersion | Should -Be '2025-11-25'
        }
    }
}
