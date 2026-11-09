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

Describe 'Get-McpDocxParagraphText' {
    It 'joins runs, tabs and breaks of a paragraph' {
        InModuleScope MCPPosh {
            $xml = [xml]'<w:p xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:r><w:t>A</w:t><w:tab/><w:t>B</w:t><w:br/><w:t>C</w:t></w:r></w:p>'
            $ns = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)
            $ns.AddNamespace('w', 'http://schemas.openxmlformats.org/wordprocessingml/2006/main')
            Get-McpDocxParagraphText -Paragraph $xml.DocumentElement -Namespaces $ns | Should -Be "A B`nC"
        }
    }
}
