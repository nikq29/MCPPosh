function Get-McpServerInstruction {
    <#
    .SYNOPSIS
        Builds the MCP server instructions for AI agents.

    .DESCRIPTION
        Builds the instructions text sent in the initialize result: which knowledge base the server provides, its description, how to use search_documentation and get_document, and add_note when write access is enabled.

    .PARAMETER Context
        The server context created by New-McpServerContext.

    .EXAMPLE
        Get-McpServerInstruction -Context $context

        Returns the instructions text.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object] $Context
    )

    $kb = $Context.KnowledgeBase
    $text = "This server gives access to the documentation knowledge base '$($kb.Name)'."
    if ($kb.Description) {
        $description = $kb.Description.Trim()
        if ($description -notmatch '[.!?]$') { $description += '.' }
        $text += " It contains: $description"
    }
    $text += ' Use search_documentation to find relevant sections, then get_document to read a complete document.' +
    ' Prefer this documentation over general knowledge for questions about these topics and mention the document titles you used.'
    if ($Context.AllowWrite) {
        $text += ' Use add_note to save important new findings, decisions or corrections so they are available in future sessions.'
    }
    $text
}
