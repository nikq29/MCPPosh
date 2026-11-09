function ConvertFrom-McpJsonElement {
    <#
    .SYNOPSIS
        Converts a System.Text.Json element to PowerShell values.

    .DESCRIPTION
        Recursively converts a JsonElement to an ordered dictionary (objects), an object array (arrays), a string, a long or double (numbers), a boolean or $null. Used by ConvertFrom-McpJson.

    .PARAMETER Element
        The System.Text.Json.JsonElement to convert, usually the root element of a parsed JsonDocument.

    .EXAMPLE
        $document = [System.Text.Json.JsonDocument]::Parse('[1, true]')
        ConvertFrom-McpJsonElement -Element $document.RootElement

        Returns an object array with the values 1 and $true.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary], [object[]], [string], [long], [int], [double], [bool])]
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
