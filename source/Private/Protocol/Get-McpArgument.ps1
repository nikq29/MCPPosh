function Get-McpArgument {
    <#
    .SYNOPSIS
        Reads and validates a tool argument. Throws an argument error (returned to the model as a tool error).

    .DESCRIPTION
        Reads a tool argument from the arguments of a tools/call request and validates its type (string, integer or string array), whether it is required and the allowed integer range. Validation errors are thrown as ArgumentException and reported to the model as tool errors so it can correct the call.

    .PARAMETER Arguments
        The arguments dictionary of the tools/call request.

    .PARAMETER Name
        Name of the argument to read, for example query or limit.

    .PARAMETER Type
        Expected type of the argument: String, Integer or StringArray.

    .PARAMETER Required
        Throws an error when the argument is missing, null or (for strings) empty.

    .PARAMETER Default
        Value returned when the argument is missing and not required.

    .PARAMETER Minimum
        Smallest allowed value for Integer arguments.

    .PARAMETER Maximum
        Largest allowed value for Integer arguments.

    .EXAMPLE
        Get-McpArgument -Arguments $arguments -Name 'limit' -Type Integer -Default 5 -Minimum 1 -Maximum 20

        Returns the limit argument or 5 when it is missing.
    #>
    [CmdletBinding()]
    [OutputType([string], [int], [string[]], [object[]])]
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
