BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Docs | Out-Null
    $script:File = Join-Path $script:TestHome 'install.md'
    Set-Content -Path $script:File -Value "# Installation`n`nInstall with winget."
    $script:Doc = Add-McpDocument -KnowledgeBase Docs -Path $script:File
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Update-McpDocument' {
    It 'does nothing when the source did not change' {
        Update-McpDocument -KnowledgeBase Docs -Id $script:Doc.Id | Should -BeNullOrEmpty
    }

    It 're-imports changed source files' {
        Set-Content -Path $script:File -Value "# Installation`n`nInstall with Chocolatey."
        $updated = Update-McpDocument -KnowledgeBase Docs -All
        $updated.Id | Should -Be $script:Doc.Id
        (Get-McpDocument -KnowledgeBase Docs -Id $script:Doc.Id -IncludeContent).Content | Should -Match 'Chocolatey'
    }

    It 're-imports URL documents' {
        InModuleScope MCPPosh {
            Mock Invoke-WebRequest {
                Set-Content -LiteralPath $OutFile -Value '# Remote'
                [pscustomobject]@{ Headers = @{ 'Content-Type' = 'text/markdown' } }
            }
            $doc = Add-McpDocument -KnowledgeBase Docs -Url 'https://example.com/remote.md'
            Mock Invoke-WebRequest {
                Set-Content -LiteralPath $OutFile -Value "# Remote`n`nChanged"
                [pscustomobject]@{ Headers = @{ 'Content-Type' = 'text/markdown' } }
            }
            (Update-McpDocument -KnowledgeBase Docs -Id $doc.Id).Id | Should -Be $doc.Id
        }
    }

    It 'warns about or removes documents whose source file is gone' {
        $temp = Join-Path $script:TestHome 'temp.md'
        Set-Content -Path $temp -Value '# Temp'
        $doc = Add-McpDocument -KnowledgeBase Docs -Path $temp
        Remove-Item $temp
        Update-McpDocument -KnowledgeBase Docs -Id $doc.Id -WarningVariable warnings -WarningAction SilentlyContinue
        $warnings | Should -Not -BeNullOrEmpty
        Update-McpDocument -KnowledgeBase Docs -Id $doc.Id -RemoveMissing
        Get-McpDocument -KnowledgeBase Docs -Id $doc.Id -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'writes an error for unknown ids' {
        Update-McpDocument -KnowledgeBase Docs -Id missing -ErrorAction SilentlyContinue -ErrorVariable err
        $err | Should -Not -BeNullOrEmpty
    }
}
