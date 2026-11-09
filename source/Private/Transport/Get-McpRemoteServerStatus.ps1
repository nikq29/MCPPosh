function Get-McpRemoteServerStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri] $Uri,

        [string] $ApiKey
    )

    $endpoint = Resolve-McpEndpointUri -Uri $Uri
    $healthUrl = $endpoint.AbsoluteUri -replace '/mcp/?$', '/health'
    $headers = @{}
    if ($ApiKey) { $headers['Authorization'] = "Bearer $ApiKey" }

    $status = 'Unreachable'
    $health = $null
    $errorMessage = $null
    try {
        $response = Invoke-WebRequest -Uri $healthUrl -Headers $headers -TimeoutSec 15 -SkipHttpErrorCheck -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            $health = ConvertFrom-McpJson -Json ([string]$response.Content)
            $status = if ($health.Contains('documents')) { 'Running' } elseif ($ApiKey) { 'Unauthorized' } else { 'Running' }
        }
        else {
            $status = "HTTP $($response.StatusCode)"
        }
    }
    catch {
        $errorMessage = $_.Exception.Message
    }

    [pscustomobject]@{
        PSTypeName    = 'MCPPosh.Server'
        KnowledgeBase = if ($health) { [string]$health['knowledgeBase'] } else { $null }
        Transport     = 'Http'
        Status        = $status
        Url           = $endpoint.AbsoluteUri
        Port          = $endpoint.Port
        ProcessId     = $null
        Documents     = if ($health -and $health.Contains('documents')) { [int]$health['documents'] } else { $null }
        Revision      = if ($health -and $health.Contains('revision')) { [long]$health['revision'] } else { $null }
        Uptime        = if ($health -and $health.Contains('uptimeSeconds')) { [timespan]::FromSeconds([double]$health['uptimeSeconds']) } else { $null }
        AuthRequired  = if ($health -and $health.Contains('authRequired')) { [bool]$health['authRequired'] } else { $null }
        AllowWrite    = if ($health -and $health.Contains('allowWrite')) { [bool]$health['allowWrite'] } else { $null }
        Version       = if ($health) { [string]$health['version'] } else { $null }
        Error         = $errorMessage
    }
}
