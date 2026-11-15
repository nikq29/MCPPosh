BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
    $script:Files = Join-Path $script:TestHome 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpWebDocument' {
    It 'converts HTML pages and resolves the title' {
        InModuleScope PSMcpKnowledgeBase {
            Mock Invoke-WebRequest {
                Set-Content -LiteralPath $OutFile -Value '<html><head><title>Online docs</title></head><body><h1>API</h1><a href="v2">next</a></body></html>'
                [pscustomobject]@{ Headers = @{ 'Content-Type' = 'text/html; charset=utf-8' } }
            }
            $result = Get-McpWebDocument -Url 'https://example.com/docs/api'
            $result.Format | Should -Be 'Html'
            $result.Title | Should -Be 'Online docs'
            $result.Content | Should -Match '\[next\]\(https://example\.com/docs/v2\)'
        }
    }

    It 'uses the converter of the content type and the URL as title fallback' {
        InModuleScope PSMcpKnowledgeBase {
            Mock Invoke-WebRequest {
                Set-Content -LiteralPath $OutFile -Value 'a,b'
                [pscustomobject]@{ Headers = @{ 'Content-Type' = 'text/csv' } }
            }
            $result = Get-McpWebDocument -Url 'https://example.com/data/report'
            $result.Format | Should -Be 'Csv'
            $result.Title | Should -Be 'report'
        }
    }

    It 'detects the format from the extension when the content type is unknown' {
        InModuleScope PSMcpKnowledgeBase {
            Mock Invoke-WebRequest {
                Set-Content -LiteralPath $OutFile -Value '# Readme'
                [pscustomobject]@{ Headers = @{ 'Content-Type' = 'application/octet-stream' } }
            }
            (Get-McpWebDocument -Url 'https://example.com/README.md').Format | Should -Be 'Markdown'
        }
    }

    It 'rejects downloads larger than the limit before converting them' {
        InModuleScope PSMcpKnowledgeBase {
            $script:McpMaxDownloadBytes = 1KB
            try {
                Mock Invoke-WebRequest {
                    Set-Content -LiteralPath $OutFile -Value ('x' * 4096) -NoNewline
                    [pscustomobject]@{ Headers = @{ 'Content-Type' = 'text/plain' } }
                }
                Mock ConvertTo-McpMarkdown { throw 'must not be called' }
                { Get-McpWebDocument -Url 'https://example.com/big.txt' } | Should -Throw '*https://example.com/big.txt*exceeds the limit of 1024 bytes*'
                Should -Invoke ConvertTo-McpMarkdown -Times 0
            }
            finally {
                $script:McpMaxDownloadBytes = 100MB
            }
        }
    }
}
