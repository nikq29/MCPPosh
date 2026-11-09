function Get-McpResourceTemplateList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context
    )

    [ordered]@{
        resourceTemplates = @(
            [ordered]@{
                uriTemplate = 'mcpposh://{0}/documents/{{id}}' -f $Context.KnowledgeBase.Name
                name        = 'document'
                title       = "Document in '$($Context.KnowledgeBase.Name)'"
                description = 'A document of the knowledge base as Markdown, addressed by its id.'
                mimeType    = 'text/markdown'
            }
        )
    }
}
