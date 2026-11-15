BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
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
        InModuleScope PSMcpKnowledgeBase {
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

    It 'only reads the source of documents whose source type is exactly File or Url (<Label>)' -ForEach @(
        @{ Label = "'file'"; SourceType = 'file' }
        @{ Label = "@('Inline', 'File')"; SourceType = @('Inline', 'File') }
        @{ Label = "'Imported'"; SourceType = 'Imported' }
    ) {
        # A manifest written by someone else (shared folder, hand-edited file) must not make Update-McpDocument read
        # files through a misspelled or non-string source type.
        $secret = Join-Path $script:TestHome 'secret.txt'
        Set-Content -Path $secret -Value 'CANARY-SECRET'
        $doc = Add-McpDocument -KnowledgeBase Docs -Title "Odd $Label" -Content 'Original text.'
        InModuleScope PSMcpKnowledgeBase -Parameters @{ Id = $doc.Id; SourceType = $SourceType; Source = $secret } {
            param($Id, $SourceType, $Source)
            $kb = Resolve-McpKnowledgeBase -KnowledgeBase Docs
            $manifest = Read-McpManifest -KbPath $kb.Path
            $record = @($manifest['documents']) | Where-Object { $_['id'] -eq $Id }
            $record['sourceType'] = $SourceType
            $record['source'] = $Source
            Save-McpManifest -KbPath $kb.Path -Manifest $manifest
        }
        Update-McpDocument -KnowledgeBase Docs -Id $doc.Id -Force | Should -BeNullOrEmpty
        (Get-McpDocument -KnowledgeBase Docs -Id $doc.Id -IncludeContent).Content | Should -Not -Match 'CANARY-SECRET'
    }

    It 'writes an error for unknown ids' {
        Update-McpDocument -KnowledgeBase Docs -Id missing -ErrorAction SilentlyContinue -ErrorVariable err
        $err | Should -Not -BeNullOrEmpty
    }
}
