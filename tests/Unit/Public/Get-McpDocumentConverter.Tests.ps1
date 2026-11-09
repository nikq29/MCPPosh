BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Get-McpDocumentConverter' {
    It 'lists the built-in converters' {
        $names = (Get-McpDocumentConverter).Name
        foreach ($name in 'Markdown', 'Text', 'Html', 'Docx', 'Pdf', 'Csv', 'Json', 'Yaml', 'Xml', 'Code') {
            $names | Should -Contain $name
        }
    }

    It 'filters by name and extension' {
        (Get-McpDocumentConverter -Name 'Mark*').Name | Should -Be 'Markdown'
        (Get-McpDocumentConverter -Extension docx).Name | Should -Be 'Docx'
        (Get-McpDocumentConverter -Extension .ps1).Name | Should -Be 'Code'
    }
}
