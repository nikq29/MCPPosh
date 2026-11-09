function Get-McpArgument {
    <#
    .SYNOPSIS
        Reads and validates a tool argument. Throws an argument error (returned to the model as a tool error).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Arguments,

        [Parameter(Mandatory)]
        [string] $Name,

        [ValidateSet('String', 'Integer', 'StringArray')]
        [string] $Type = 'String',

        [switch] $Required,

        [object] $Default,

        [int] $Minimum = [int]::MinValue,

        [int] $Maximum = [int]::MaxValue
    )

    if (-not $Arguments.Contains($Name) -or $null -eq $Arguments[$Name]) {
        if ($Required) { throw [System.ArgumentException]::new("Missing required argument '$Name'.") }
        return $Default
    }
    $value = $Arguments[$Name]
    switch ($Type) {
        'String' {
            if ($value -isnot [string]) { throw [System.ArgumentException]::new("Argument '$Name' must be a string.") }
            if ($Required -and [string]::IsNullOrWhiteSpace($value)) { throw [System.ArgumentException]::new("Argument '$Name' must not be empty.") }
            return $value
        }
        'Integer' {
            if ($value -is [double] -and $value -eq [Math]::Floor($value)) { $value = [long]$value }
            if ($value -is [string] -and $value -match '^-?\d+$') { $value = [long]$value }
            if ($value -isnot [long] -and $value -isnot [int]) { throw [System.ArgumentException]::new("Argument '$Name' must be an integer.") }
            if ($value -lt $Minimum -or $value -gt $Maximum) { throw [System.ArgumentException]::new("Argument '$Name' must be between $Minimum and $Maximum.") }
            return [int]$value
        }
        'StringArray' {
            if ($value -is [string]) { return , [string[]]@($value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
            if ($value -isnot [array]) { throw [System.ArgumentException]::new("Argument '$Name' must be an array of strings.") }
            foreach ($item in $value) {
                if ($item -isnot [string]) { throw [System.ArgumentException]::new("Argument '$Name' must be an array of strings.") }
            }
            return , [string[]]$value
        }
    }
}
