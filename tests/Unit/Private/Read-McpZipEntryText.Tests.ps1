BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    $script:Files = Join-Path $script:TestHome 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Read-McpZipEntryText' {
    It 'reads an entry and returns $null for missing entries' {
        $docx = Join-Path $script:Files 'zip.docx'
        New-McpTestDocx -Path $docx
        InModuleScope MCPPosh -Parameters @{ Path = $docx } {
            param($Path)
            $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
            try {
                Read-McpZipEntryText -Archive $archive -EntryName 'word/document.xml' | Should -Match 'Operations Handbook'
                Read-McpZipEntryText -Archive $archive -EntryName 'missing.xml' | Should -BeNullOrEmpty
            }
            finally {
                $archive.Dispose()
            }
        }
    }
}
