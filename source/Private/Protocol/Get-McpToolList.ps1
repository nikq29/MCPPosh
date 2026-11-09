function Get-McpToolList {
    <#
    .SYNOPSIS
        Handles the MCP method tools/list.

    .DESCRIPTION
        Returns the tool definitions with JSON schemas and annotations: search_documentation, get_document and list_documents, plus add_note when the server was started with write access. The descriptions name the knowledge base.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .EXAMPLE
        (Get-McpToolList -Context $context).tools.name

        Returns search_documentation, get_document and list_documents.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)]
        [object] $Context
    )

    $kb = $Context.KnowledgeBase
    $about = if ($kb.Description) { " ($($kb.Description))" } else { '' }

    $tools = [System.Collections.Generic.List[object]]::new()
    $tools.Add([ordered]@{
            name        = 'search_documentation'
            title       = 'Search documentation'
            description = "Search the '$($kb.Name)' documentation knowledge base$about. Returns the most relevant sections with their document ids. Use specific keywords or a short question. Call get_document to read a complete document."
            inputSchema = [ordered]@{
                type       = 'object'
                properties = [ordered]@{
                    query = [ordered]@{ type = 'string'; description = 'Search terms or a short natural-language question.' }
                    limit = [ordered]@{ type = 'integer'; description = 'Maximum number of sections to return (1-20, default 5).'; minimum = 1; maximum = 20; default = 5 }
                    tags  = [ordered]@{ type = 'array'; items = [ordered]@{ type = 'string' }; description = 'Only search documents that have at least one of these tags.' }
                }
                required   = @('query')
            }
            annotations = [ordered]@{ readOnlyHint = $true; openWorldHint = $false }
        })
    $tools.Add([ordered]@{
            name        = 'get_document'
            title       = 'Read document'
            description = "Read a complete document from the '$($kb.Name)' knowledge base as Markdown. Long documents are returned in pages; use offset to continue."
            inputSchema = [ordered]@{
                type       = 'object'
                properties = [ordered]@{
                    id       = [ordered]@{ type = 'string'; description = 'Document id as returned by search_documentation or list_documents.' }
                    offset   = [ordered]@{ type = 'integer'; description = 'Character offset to start reading from (default 0).'; minimum = 0; default = 0 }
                    maxChars = [ordered]@{ type = 'integer'; description = 'Maximum number of characters to return (500-100000, default 20000).'; minimum = 500; maximum = 100000; default = 20000 }
                }
                required   = @('id')
            }
            annotations = [ordered]@{ readOnlyHint = $true; openWorldHint = $false }
        })
    $tools.Add([ordered]@{
            name        = 'list_documents'
            title       = 'List documents'
            description = "List the documents in the '$($kb.Name)' knowledge base with id, title, tags and a short summary."
            inputSchema = [ordered]@{
                type       = 'object'
                properties = [ordered]@{
                    tag    = [ordered]@{ type = 'string'; description = 'Only list documents with this tag.' }
                    limit  = [ordered]@{ type = 'integer'; description = 'Maximum number of documents (1-500, default 100).'; minimum = 1; maximum = 500; default = 100 }
                    offset = [ordered]@{ type = 'integer'; description = 'Number of documents to skip (default 0).'; minimum = 0; default = 0 }
                }
            }
            annotations = [ordered]@{ readOnlyHint = $true; openWorldHint = $false }
        })
    if ($Context.AllowWrite) {
        $tools.Add([ordered]@{
                name        = 'add_note'
                title       = 'Add note'
                description = "Save a note (Markdown) in the '$($kb.Name)' knowledge base, e.g. a finding, decision or correction. A note with the same title is updated."
                inputSchema = [ordered]@{
                    type       = 'object'
                    properties = [ordered]@{
                        title   = [ordered]@{ type = 'string'; description = 'Short, descriptive title.' }
                        content = [ordered]@{ type = 'string'; description = 'Note content in Markdown.' }
                        tags    = [ordered]@{ type = 'array'; items = [ordered]@{ type = 'string' }; description = 'Optional tags.' }
                    }
                    required   = @('title', 'content')
                }
                annotations = [ordered]@{ readOnlyHint = $false; destructiveHint = $false; idempotentHint = $true; openWorldHint = $false }
            })
    }

    [ordered]@{ tools = $tools.ToArray() }
}
