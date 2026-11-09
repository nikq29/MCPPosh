function New-McpToolResult {
    <#
    .SYNOPSIS
        Creates the result of an MCP tool call.

    .DESCRIPTION
        Creates a tools/call result with a single text content block, optional structured content for clients that support it and the isError flag for tool execution errors.

    .PARAMETER Text
        The text shown to the model, usually Markdown.

    .PARAMETER Structured
        Optional structured content (structuredContent) with the same information as data.

    .PARAMETER IsError
        Marks the result as a tool execution error that the model should handle.

    .EXAMPLE
        New-McpToolResult -Text 'No matching sections found.' -Structured ([ordered]@{ results = @() })

        Returns a tool result with text and structured content.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates an in-memory result object only; no system state is changed.')]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text,

        [object] $Structured,

        [switch] $IsError
    )

    $result = [ordered]@{
        content = @([ordered]@{ type = 'text'; text = $Text })
    }
    if ($null -ne $Structured) { $result['structuredContent'] = $Structured }
    if ($IsError) { $result['isError'] = $true }
    $result
}
