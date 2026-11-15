BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpSha256' {
    It 'hashes text as UTF-8' {
        InModuleScope PSMcpKnowledgeBase {
            Get-McpSha256 -Text 'hello' | Should -Be '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824'
        }
    }

    It 'hashes files' {
        InModuleScope PSMcpKnowledgeBase -Parameters @{ Home = $script:TestHome } {
            param($Home)
            $file = Join-Path $Home 'hash.txt'
            [System.IO.File]::WriteAllText($file, 'hello')
            Get-McpSha256 -Path $file | Should -Be (Get-McpSha256 -Text 'hello')
        }
    }
}
