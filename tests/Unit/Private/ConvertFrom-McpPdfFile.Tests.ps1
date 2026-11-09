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

Describe 'ConvertFrom-McpPdfFile' {
    It 'turns form feeds into paragraph breaks' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'manual.pdf'
            Set-Content -Path $path -Value '%PDF-1.4 fake'
            Mock Invoke-McpPdfTextExtraction { "Page one`fPage two" }
            (ConvertFrom-McpPdfFile -Path $path).Content | Should -Be "Page one`n`nPage two"
        }
    }
}
