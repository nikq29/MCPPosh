function Read-McpTextFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $attempt = 0
    while ($true) {
        try {
            # ReadAllText detects and strips a BOM; UTF-8 is the fallback.
            return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        }
        catch [System.IO.IOException] {
            if (++$attempt -ge 20) { throw }
            Start-Sleep -Milliseconds 50
        }
    }
}
