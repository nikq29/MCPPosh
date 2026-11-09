function Get-McpDocument {
    <#
    .SYNOPSIS
        Lists the documents of a knowledge base.

    .DESCRIPTION
        Returns the documents stored in a knowledge base as MCPPosh.Document objects. Filter by id, title, tag, format or source type, and add the Markdown content with -IncludeContent.

    .PARAMETER Id
        Document ids (wildcards allowed).

    .PARAMETER Title
        Filter by title (wildcards allowed).

    .PARAMETER Tag
        Only documents that have at least one of these tags.

    .PARAMETER Format
        Only documents of these formats (Markdown, Html, Docx, ...).

    .PARAMETER SourceType
        Only documents from these sources: File, Url, Inline or Agent (notes added by the AI agent).

    .PARAMETER IncludeContent
        Adds the Markdown content as a Content property.

    .PARAMETER KnowledgeBase
        Name or directory path of the knowledge base. The knowledge base named Default is created automatically.

    .EXAMPLE
        Get-McpDocument -KnowledgeBase Contoso -Tag runbook

    .EXAMPLE
        Get-McpDocument -Title '*VPN*' -IncludeContent | Select-Object -ExpandProperty Content
    #>
    [CmdletBinding()]
    [OutputType('MCPPosh.Document')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [string[]] $Id = '*',

        [SupportsWildcards()]
        [string] $Title,

        [string[]] $Tag,

        [string[]] $Format,

        [ValidateSet('File', 'Url', 'Inline', 'Agent')]
        [string[]] $SourceType,

        [switch] $IncludeContent,

        [string] $KnowledgeBase = 'Default'
    )

    begin {
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase -CreateIfMissing:($KnowledgeBase -eq 'Default')
        $documents = @((Read-McpManifest -KbPath $kb.Path)['documents'])
    }

    process {
        foreach ($pattern in $Id) {
            $matched = @($documents | Where-Object { $_.id -like $pattern })
            if ($matched.Count -eq 0 -and -not [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($pattern)) {
                Write-Error -Message "Document '$pattern' was not found in knowledge base '$($kb.Name)'." -Category ObjectNotFound -TargetObject $pattern
                continue
            }
            foreach ($record in $matched) {
                if ($Title -and $record.title -notlike $Title) { continue }
                if ($Tag -and -not (@($record.tags) | Where-Object { $Tag -contains $_ })) { continue }
                if ($Format -and $Format -notcontains $record.format) { continue }
                if ($SourceType -and $SourceType -notcontains $record.sourceType) { continue }
                ConvertTo-McpDocumentObject -Record $record -KnowledgeBase $kb -IncludeContent:$IncludeContent
            }
        }
    }
}
