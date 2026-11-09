function ConvertTo-McpShellArgument {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowEmptyString()]
        [string] $Value
    )

    if ($Value -match '^[\w./:=@-]+$') { return $Value }
    if ($IsWindows) { return '"' + $Value.Replace('"', '\"') + '"' }
    "'" + $Value.Replace("'", "'\''") + "'"
}
