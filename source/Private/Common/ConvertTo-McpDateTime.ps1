function ConvertTo-McpDateTime {
    <#
    .SYNOPSIS
        Converts a stored timestamp to a DateTime value.

    .DESCRIPTION
        Converts an ISO 8601 timestamp string from a manifest or state file to a UTC DateTime. DateTime values are returned unchanged and empty values return $null.

    .PARAMETER Value
        The timestamp to convert: an ISO 8601 string, a DateTime value, an empty string or $null.

    .EXAMPLE
        ConvertTo-McpDateTime -Value '2026-01-31T08:15:00.000Z'

        Returns the DateTime 2026-01-31 08:15:00 (UTC).
    #>
    [CmdletBinding()]
    [OutputType([datetime])]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value -or $Value -eq '') { return $null }
    if ($Value -is [datetime]) { return $Value }
    [datetime]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal)
}
