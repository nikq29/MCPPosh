@{
    # Script module or binary module file associated with this manifest.
    RootModule           = 'MCPPosh.psm1'

    # Version number of this module. Set by the Sampler build (GitVersion).
    ModuleVersion        = '0.0.1'

    # ID used to uniquely identify this module
    GUID                 = 'a4c5aad7-b202-47f2-b38d-baca8f8a568f'

    Author               = 'nikq29'
    CompanyName          = 'nikq29'
    Copyright            = '(c) nikq29. All rights reserved.'

    Description          = 'Host a Model Context Protocol (MCP) server that serves your own documentation to AI agents, and manage the server and its knowledge base entirely from PowerShell. Supports stdio and Streamable HTTP, imports Markdown, text, HTML/web pages, Word (.docx), PDF, CSV, JSON/YAML/XML and source code, and ships a local BM25 search.'

    PowerShellVersion    = '7.2'
    CompatiblePSEditions = @('Core')

    RequiredModules      = @()

    # Filled by ModuleBuilder from the files in the Public folder.
    FunctionsToExport    = @()
    CmdletsToExport      = @()
    VariablesToExport    = @()
    AliasesToExport      = @()

    PrivateData          = @{
        PSData = @{
            Tags         = @('MCP', 'ModelContextProtocol', 'AI', 'Agent', 'LLM', 'Documentation', 'KnowledgeBase', 'Claude', 'Copilot', 'RAG', 'PSEdition_Core', 'Windows', 'Linux', 'MacOS')
            LicenseUri   = 'https://github.com/nikq29/MCPPosh/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/nikq29/MCPPosh'
            ReleaseNotes = ''
            Prerelease   = ''
        }
    }
}
