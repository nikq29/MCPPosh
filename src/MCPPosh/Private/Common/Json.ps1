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

function ConvertFrom-McpJsonElement {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Text.Json.JsonElement] $Element
    )

    switch ($Element.ValueKind) {
        ([System.Text.Json.JsonValueKind]::Object) {
            $result = [ordered]@{}
            foreach ($property in $Element.EnumerateObject()) {
                $result[$property.Name] = ConvertFrom-McpJsonElement -Element $property.Value
            }
            return $result
        }
        ([System.Text.Json.JsonValueKind]::Array) {
            $items = [System.Collections.Generic.List[object]]::new()
            foreach ($item in $Element.EnumerateArray()) {
                $items.Add((ConvertFrom-McpJsonElement -Element $item))
            }
            return , $items.ToArray()
        }
        ([System.Text.Json.JsonValueKind]::String) {
            return $Element.GetString()
        }
        ([System.Text.Json.JsonValueKind]::Number) {
            [long] $long = 0
            if ($Element.TryGetInt64([ref] $long)) {
                return $long
            }
            return $Element.GetDouble()
        }
        ([System.Text.Json.JsonValueKind]::True) {
            return $true
        }
        ([System.Text.Json.JsonValueKind]::False) {
            return $false
        }
        default {
            return $null
        }
    }
}

function ConvertTo-McpJson {
    <#
    .SYNOPSIS
        Serializes an object to JSON without unrolling arrays and without depth warnings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object] $InputObject,

        [switch] $Compress
    )

    ConvertTo-Json -InputObject $InputObject -Depth 64 -Compress:$Compress -WarningAction SilentlyContinue
}

function Read-McpJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    $text = Read-McpTextFile -Path $Path
    if ([string]::IsNullOrWhiteSpace($text)) {
        return $null
    }
    ConvertFrom-McpJson -Json $text
}

function Write-McpJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $InputObject
    )

    Write-McpTextFile -Path $Path -Content (ConvertTo-McpJson -InputObject $InputObject)
}
