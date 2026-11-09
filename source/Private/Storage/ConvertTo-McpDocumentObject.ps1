function ConvertTo-McpDocumentObject {
    <#
    .SYNOPSIS
        Converts a manifest record to a document object.

    .DESCRIPTION
        Converts a document record from manifest.json to an MCPPosh.Document object with Id, Title, Format, Tags, source information, timestamps and the resource URI, optionally including the Markdown content.

    .PARAMETER Record
        The document record from the manifest, an ordered dictionary with id, title, format and the other fields.

    .PARAMETER KnowledgeBase
        The resolved knowledge base (see Resolve-McpKnowledgeBase) that contains the document.

    .PARAMETER IncludeContent
        Adds the Markdown content of the document as the Content property.

    .EXAMPLE
        $record = (Read-McpManifest -KbPath $kb.Path).documents[0]
        ConvertTo-McpDocumentObject -Record $record -KnowledgeBase $kb -IncludeContent

        Returns the first document of the knowledge base with its content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Record,

        [Parameter(Mandatory)]
        [object] $KnowledgeBase,

        [switch] $IncludeContent
    )

    $object = [ordered]@{
        PSTypeName    = 'MCPPosh.Document'
        Id            = [string]$Record.id
        Title         = [string]$Record.title
        Format        = [string]$Record.format
        Tags          = [string[]]@($Record.tags | Where-Object { $_ })
        SourceType    = [string]$Record.sourceType
        Source        = $Record.source
        Summary       = [string]$Record.summary
        Chars         = [int]$Record.chars
        Added         = ConvertTo-McpDateTime -Value $Record.added
        Updated       = ConvertTo-McpDateTime -Value $Record.updated
        KnowledgeBase = $KnowledgeBase.Name
        Uri           = 'mcpposh://{0}/documents/{1}' -f $KnowledgeBase.Name, $Record.id
    }
    if ($IncludeContent) {
        $object['Content'] = Get-McpDocumentContent -KbPath $KnowledgeBase.Path -Id $Record.id
    }
    [pscustomobject]$object
}
