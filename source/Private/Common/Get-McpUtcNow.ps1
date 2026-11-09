function Get-McpUtcNow {
    <#
    .SYNOPSIS
        Returns the current UTC time as an ISO 8601 string.

    .DESCRIPTION
        Returns the current UTC time formatted as yyyy-MM-ddTHH:mm:ss.fffZ with the invariant culture. All timestamps in manifests and state files use this format.

    .EXAMPLE
        Get-McpUtcNow

        Returns for example 2026-11-09T06:31:16.123Z.
    #>
    [System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
}
