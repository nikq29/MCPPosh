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

Describe 'Get-McpConverter' {
    It 'finds converters by extension, file name and format' {
        InModuleScope MCPPosh {
            (Get-McpConverter -Path 'handbook.docx').Name | Should -Be 'Docx'
            (Get-McpConverter -Path 'settings.yml').Name | Should -Be 'Yaml'
            (Get-McpConverter -Path '/src/Dockerfile').Name | Should -Be 'Code'
            (Get-McpConverter -Format 'Pdf').Name | Should -Be 'Pdf'
        }
    }

    It 'falls back to Text for unknown text files and throws for unknown formats' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'notes.unknownext'
            Set-Content -Path $path -Value 'text'
            (Get-McpConverter -Path $path).Name | Should -Be 'Text'
            { Get-McpConverter -Format 'Nope' } | Should -Throw '*Unknown format*'
        }
    }
}
