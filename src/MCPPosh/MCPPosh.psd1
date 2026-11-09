@{
    RootModule           = 'MCPPosh.psm1'
    ModuleVersion        = '0.1.0'
    GUID                 = 'a4c5aad7-b202-47f2-b38d-baca8f8a568f'
    Author               = 'MCPPosh contributors'
    CompanyName          = 'Community'
    Copyright            = '(c) MCPPosh contributors. All rights reserved.'
    Description          = 'Host a Model Context Protocol (MCP) server that serves your own documentation to AI agents, and manage the server and its knowledge base entirely from PowerShell. Supports stdio and Streamable HTTP, imports Markdown, text, HTML/web pages, Word (.docx), PDF, CSV, JSON/YAML/XML and source code, and ships a local BM25 search.'
    PowerShellVersion    = '7.2'
    CompatiblePSEditions = @('Core')

    FunctionsToExport    = @(
        # Knowledge bases
        'New-McpKnowledgeBase'
        'Get-McpKnowledgeBase'
        'Set-McpKnowledgeBase'
        'Remove-McpKnowledgeBase'
        'Export-McpKnowledgeBase'
        'Import-McpKnowledgeBase'
        'Publish-McpKnowledgeBase'
        # Documents
        'Add-McpDocument'
        'Get-McpDocument'
        'Set-McpDocument'
        'Update-McpDocument'
        'Remove-McpDocument'
        'Search-McpDocument'
        'Register-McpDocumentConverter'
        'Get-McpDocumentConverter'
        'Unregister-McpDocumentConverter'
        # Server
        'Start-McpServer'
        'Stop-McpServer'
        'Restart-McpServer'
        'Get-McpServer'
        'Test-McpServer'
        'Get-McpServerLog'
        # Clients
        'Get-McpClientConfig'
    )
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @('MCP', 'ModelContextProtocol', 'AI', 'Agent', 'LLM', 'Documentation', 'KnowledgeBase', 'Claude', 'Copilot', 'RAG', 'PSEdition_Core', 'Windows', 'Linux', 'MacOS')
            ProjectUri   = 'https://github.com/nikq29/MCPPosh'
            ReleaseNotes = 'Initial release: knowledge base management, multi-format import, BM25 search, MCP server over stdio and Streamable HTTP, background server management, client configuration and Azure hosting.'
        }
    }
}
