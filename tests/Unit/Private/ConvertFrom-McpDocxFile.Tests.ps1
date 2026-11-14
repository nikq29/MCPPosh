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

Describe 'ConvertFrom-McpDocxFile' {
    BeforeAll {
        $script:DocxPath = Join-Path $script:Files 'handbook.docx'
        New-McpTestDocx -Path $script:DocxPath
        $script:Docx = InModuleScope MCPPosh -Parameters @{ Path = $script:DocxPath } { param($Path) ConvertFrom-McpDocxFile -Path $Path }
    }

    It 'uses the title from the document properties' {
        $script:Docx.Title | Should -Be 'Emergency Handbook'
    }

    It 'maps localized heading styles to Markdown headings and joins runs' {
        $script:Docx.Content | Should -Match '(?m)^# Operations Handbook$'
        $script:Docx.Content | Should -Match '(?m)^## Escalation$'
        $script:Docx.Content | Should -Match 'This handbook describes the emergency mode\.'
    }

    It 'converts nested lists and tables' {
        $script:Docx.Content | Should -Match '(?m)^- Call the control center$'
        $script:Docx.Content | Should -Match '(?m)^  - Create a ticket$'
        $script:Docx.Content | Should -Match '(?m)^\| Level \| Contact \|$'
        $script:Docx.Content | Should -Match '\| 1 \| Service desk \\\| 24/7 \|'
    }

    It 'rejects files that are not Word documents' {
        $zip = Join-Path $script:Files 'notword.docx'
        Compress-Archive -Path $script:DocxPath -DestinationPath (Join-Path $script:Files 'tmp.zip') -Force
        Move-Item (Join-Path $script:Files 'tmp.zip') $zip -Force
        InModuleScope MCPPosh -Parameters @{ Path = $zip } { param($Path) { ConvertFrom-McpDocxFile -Path $Path } | Should -Throw '*not a valid Word document*' }
    }

    It 'rejects Word documents whose XML contains a document type definition' {
        $path = Join-Path $script:Files 'entities.docx'
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
        $archive = [System.IO.Compression.ZipFile]::Open($path, [System.IO.Compression.ZipArchiveMode]::Create)
        try {
            $entry = $archive.CreateEntry('word/document.xml')
            $writer = [System.IO.StreamWriter]::new($entry.Open())
            $writer.Write('<?xml version="1.0"?><!DOCTYPE w:document [<!ENTITY a "aaaaaaaaaa">]><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p><w:r><w:t>&a;</w:t></w:r></w:p></w:body></w:document>')
            $writer.Dispose()
        }
        finally {
            $archive.Dispose()
        }
        InModuleScope MCPPosh -Parameters @{ Path = $path } { param($Path) { ConvertFrom-McpDocxFile -Path $Path } | Should -Throw '*document type definition*' }
    }
}
