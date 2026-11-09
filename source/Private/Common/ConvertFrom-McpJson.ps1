function ConvertFrom-McpJson {
    <#
    .SYNOPSIS
        Parses JSON into ordered dictionaries, object arrays and primitive values.

    .DESCRIPTION
        Parses JSON text with System.Text.Json and converts it to ordered dictionaries, object arrays and primitive values. Unlike ConvertFrom-Json, ISO 8601 strings stay strings and integers keep their type, which matters for JSON-RPC request ids.

    .PARAMETER Json
        The JSON text to parse. Comments and trailing commas are tolerated.

    .EXAMPLE
        ConvertFrom-McpJson -Json '{"jsonrpc":"2.0","id":1,"method":"ping"}'

        Returns an ordered dictionary whose id is a [long] and whose method is a string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Json
    )

    $options = [System.Text.Json.JsonDocumentOptions]::new()
    $options.MaxDepth = 128
    $options.AllowTrailingCommas = $true
    $options.CommentHandling = [System.Text.Json.JsonCommentHandling]::Skip
    $document = [System.Text.Json.JsonDocument]::Parse($Json, $options)
    try {
        ConvertFrom-McpJsonElement -Element $document.RootElement
    }
    finally {
        $document.Dispose()
    }
}
