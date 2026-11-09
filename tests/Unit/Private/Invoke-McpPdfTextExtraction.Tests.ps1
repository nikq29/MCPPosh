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

Describe 'Invoke-McpPdfTextExtraction' {
    It 'uses PSWritePDF when it is installed' {
        InModuleScope MCPPosh {
            function Convert-PDFToText { param($FilePath) 'page 1', 'page 2' }
            Mock Get-Module { [pscustomobject]@{ Name = 'PSWritePDF' } } -ParameterFilter { $Name -eq 'PSWritePDF' }
            Mock Import-Module { } -ParameterFilter { $Name -eq 'PSWritePDF' }
            Invoke-McpPdfTextExtraction -Path 'manual.pdf' | Should -Be "page 1`n`npage 2"
        }
    }

    It 'explains how to enable PDF support when no extractor is available' {
        InModuleScope MCPPosh {
            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'PSWritePDF' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'pdftotext' }
            { Invoke-McpPdfTextExtraction -Path 'manual.pdf' } | Should -Throw '*PSWritePDF*pdftotext*'
        }
    }
}
