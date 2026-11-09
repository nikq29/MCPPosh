function Get-McpResourceTemplateList {
    <#
    .SYNOPSIS
        Handles the MCP method resources/templates/list.

    .DESCRIPTION
        Returns the resource template mcpposh://<knowledge base>/documents/{id}, which clients can use to read any document of the knowledge base by its id.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .EXAMPLE
        Get-McpResourceTemplateList -Context $context

        Returns the resourceTemplates result with one template.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
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
