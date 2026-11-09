function Invoke-McpStdioRpc {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Client,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Message,

        [int] $TimeoutSeconds = 30
    )

    $Client.Process.StandardInput.WriteLine((ConvertTo-McpJson -Compress -InputObject $Message))
    $Client.Process.StandardInput.Flush()
    if (-not $Message.Contains('id')) { return $null }

    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    while ($true) {
        $remaining = [int]($deadline - [datetime]::UtcNow).TotalMilliseconds
        if ($remaining -le 0) { throw "Timed out after $TimeoutSeconds seconds waiting for a response to '$($Message['method'])'." }
        $readTask = $Client.Process.StandardOutput.ReadLineAsync()
        if (-not $readTask.Wait($remaining)) { throw "Timed out after $TimeoutSeconds seconds waiting for a response to '$($Message['method'])'." }
        $line = $readTask.Result
        if ($null -eq $line) {
            $stderr = if ($Client.ErrorTask.Wait(2000)) { $Client.ErrorTask.Result } else { '' }
            throw "The stdio server exited unexpectedly. $stderr"
        }
        try {
            $parsed = ConvertFrom-McpJson -Json $line
        }
        catch {
            throw "The stdio server wrote non-JSON output to stdout: $line"
        }
        if ($parsed -is [System.Collections.IDictionary] -and $parsed['id'] -eq $Message['id']) { return $parsed }
    }
}
