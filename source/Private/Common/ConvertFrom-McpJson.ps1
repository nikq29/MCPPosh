function ConvertFrom-McpJson {
    <#
    .SYNOPSIS
        Parses JSON into ordered dictionaries, object arrays and primitive values.
    .DESCRIPTION
        Uses System.Text.Json instead of ConvertFrom-Json so that strings stay strings
        (ConvertFrom-Json turns ISO-8601 looking strings into DateTime objects) and
        integers keep their type, which matters for JSON-RPC request ids.
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
