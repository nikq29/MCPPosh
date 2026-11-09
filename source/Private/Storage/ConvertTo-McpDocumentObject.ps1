function ConvertTo-McpDocumentObject {
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
