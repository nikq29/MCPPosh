BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/PSMcpKnowledgeBase.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'PSMcpKnowledgeBase'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertTo-McpXmlDocument' {
    It 'parses XML into an XmlDocument' {
        InModuleScope PSMcpKnowledgeBase {
            $document = ConvertTo-McpXmlDocument -Xml '<?xml version="1.0" encoding="UTF-8"?><root><item name="a">text</item></root>'
            $document | Should -BeOfType [System.Xml.XmlDocument]
            $document.root.item.name | Should -Be 'a'
            $document.root.item.'#text' | Should -Be 'text'
        }
    }

    It 'rejects XML with a document type definition (entity expansion, external entities)' {
        InModuleScope PSMcpKnowledgeBase {
            $bomb = '<?xml version="1.0"?><!DOCTYPE root [<!ENTITY a "aaaaaaaaaa"><!ENTITY b "&a;&a;&a;&a;&a;&a;&a;&a;&a;&a;">]><root>&b;</root>'
            { ConvertTo-McpXmlDocument -Xml $bomb -Description 'test.xml' } | Should -Throw '*test.xml*document type definition*'
            $external = '<?xml version="1.0"?><!DOCTYPE root [<!ENTITY x SYSTEM "file:///etc/passwd">]><root>&x;</root>'
            { ConvertTo-McpXmlDocument -Xml $external } | Should -Throw '*document type definition*'
        }
    }

    It 'reports malformed XML' {
        InModuleScope PSMcpKnowledgeBase {
            { ConvertTo-McpXmlDocument -Xml '<root><unclosed></root>' } | Should -Throw
        }
    }
}
