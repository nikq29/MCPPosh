function Invoke-McpMessage {
    <#
    .SYNOPSIS
        Handles one raw JSON-RPC message (single request, notification or batch).
    .OUTPUTS
        The JSON response text, or $null when nothing has to be sent back (notifications).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Json
    )

    try {
        $message = ConvertFrom-McpJson -Json $Json
    }
    catch {
        Write-McpLog -Context $Context -Level WARN -Message "Parse error: $($_.Exception.Message)"
        return ConvertTo-McpJson -Compress -InputObject (New-McpErrorResponse -Id $null -Code -32700 -Message 'Parse error')
    }

    if ($message -is [array]) {
        if ($message.Count -eq 0) {
            return ConvertTo-McpJson -Compress -InputObject (New-McpErrorResponse -Id $null -Code -32600 -Message 'Invalid Request: empty batch')
        }
        $responses = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $message) {
            $response = Invoke-McpRequest -Context $Context -Message $item
            if ($null -ne $response) { $responses.Add($response) }
        }
        if ($responses.Count -eq 0) { return $null }
        return ConvertTo-McpJson -Compress -InputObject $responses.ToArray()
    }

    $single = Invoke-McpRequest -Context $Context -Message $message
    if ($null -eq $single) { return $null }
    ConvertTo-McpJson -Compress -InputObject $single
}

function New-McpErrorResponse {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Id,

        [Parameter(Mandatory)]
        [int] $Code,

        [Parameter(Mandatory)]
        [string] $Message,

        [object] $Data
    )

    $errorObject = [ordered]@{ code = $Code; message = $Message }
    if ($null -ne $Data) { $errorObject['data'] = $Data }
    [ordered]@{ jsonrpc = '2.0'; id = $Id; error = $errorObject }
}

function Invoke-McpRequest {
    <#
    .SYNOPSIS
        Validates and dispatches a parsed JSON-RPC message.
    .OUTPUTS
        A response dictionary, or $null for notifications and client responses.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [AllowNull()]
        [object] $Message
    )

    if ($Message -isnot [System.Collections.IDictionary]) {
        return New-McpErrorResponse -Id $null -Code -32600 -Message 'Invalid Request'
    }

    $hasId = $Message.Contains('id')
    $id = if ($hasId) { $Message['id'] } else { $null }
    $method = $Message['method']

    if ($Message['jsonrpc'] -ne '2.0' -or ($null -ne $method -and $method -isnot [string]) -or ($hasId -and $null -ne $id -and $id -isnot [string] -and $id -isnot [long] -and $id -isnot [double])) {
        return New-McpErrorResponse -Id $id -Code -32600 -Message 'Invalid Request'
    }

    if ($null -eq $method) {
        # A response to a server-initiated request; this server sends none, so ignore it.
        return $null
    }

    if (-not $hasId) {
        Invoke-McpNotification -Context $Context -Method $method -Params $Message['params']
        return $null
    }

    $Context.RequestCount++
    $params = $Message['params']
    if ($null -ne $params -and $params -isnot [System.Collections.IDictionary]) {
        return New-McpErrorResponse -Id $id -Code -32602 -Message 'Invalid params: params must be an object'
    }
    if ($null -eq $params) { $params = [ordered]@{} }

    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $result = switch ($method) {
            'initialize' { Invoke-McpInitialize -Context $Context -Params $params; break }
            'ping' { [ordered]@{}; break }
            'tools/list' { Get-McpToolList -Context $Context; break }
            'tools/call' { Invoke-McpToolCall -Context $Context -Params $params; break }
            'resources/list' { Get-McpResourceList -Context $Context -Params $params; break }
            'resources/templates/list' { Get-McpResourceTemplateList -Context $Context; break }
            'resources/read' { Read-McpResource -Context $Context -Params $params; break }
            'prompts/list' { [ordered]@{ prompts = @() }; break }
            'logging/setLevel' { [ordered]@{}; break }
            default { throw (New-McpRpcError -Code -32601 -Message "Method not found: $method") }
        }
        Write-McpLog -Context $Context -Level DEBUG -Message ('{0} ok ({1} ms)' -f $method, $watch.ElapsedMilliseconds)
        [ordered]@{ jsonrpc = '2.0'; id = $id; result = $result }
    }
    catch {
        $exception = $_.Exception
        $code = $exception.Data['McpRpcCode']
        if ($null -eq $code) {
            Write-McpLog -Context $Context -Level ERROR -Message ("{0} failed: {1}" -f $method, $exception.Message)
            return New-McpErrorResponse -Id $id -Code -32603 -Message "Internal error: $($exception.Message)"
        }
        Write-McpLog -Context $Context -Level WARN -Message ("{0} rejected ({1}): {2}" -f $method, $code, $exception.Message)
        New-McpErrorResponse -Id $id -Code ([int]$code) -Message $exception.Message -Data $exception.Data['McpRpcData']
    }
}

function Invoke-McpNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [string] $Method,

        [object] $Params
    )

    switch ($Method) {
        'notifications/initialized' { Write-McpLog -Context $Context -Message 'Client initialized' }
        'notifications/cancelled' { Write-McpLog -Context $Context -Level DEBUG -Message 'Client cancelled a request' }
        default { Write-McpLog -Context $Context -Level DEBUG -Message "Ignored notification: $Method" }
    }
}

function Invoke-McpInitialize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object] $Context,

        [Parameter(Mandatory)]
        [System.Collections.IDictionary] $Params
    )

    $requested = [string]$Params['protocolVersion']
    $version = if ($requested -and $script:McpSupportedProtocolVersions -contains $requested) {
        $requested
    }
    else {
        $script:McpSupportedProtocolVersions[0]
    }
    $Context.ProtocolVersion = $version
    $Context.ClientInfo = $Params['clientInfo']

    $clientName = if ($Params['clientInfo']) { '{0} {1}' -f $Params['clientInfo']['name'], $Params['clientInfo']['version'] } else { 'unknown client' }
    Write-McpLog -Context $Context -Message "initialize from $clientName (requested $requested, using $version)"

    $null = Update-McpServerIndex -Context $Context
    $kb = $Context.KnowledgeBase
    [ordered]@{
        protocolVersion = $version
        capabilities    = [ordered]@{
            tools     = [ordered]@{ listChanged = $false }
            resources = [ordered]@{ subscribe = $false; listChanged = $false }
        }
        serverInfo      = [ordered]@{
            name    = 'MCPPosh'
            title   = "MCPPosh - $($kb.Name)"
            version = $script:ModuleVersion
        }
        instructions    = Get-McpServerInstructions -Context $Context
    }
}

function Get-McpServerInstructions {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [object] $Context
    )

    $kb = $Context.KnowledgeBase
    $text = "This server gives access to the documentation knowledge base '$($kb.Name)'."
    if ($kb.Description) {
        $description = $kb.Description.Trim()
        if ($description -notmatch '[.!?]$') { $description += '.' }
        $text += " It contains: $description"
    }
    $text += ' Use search_documentation to find relevant sections, then get_document to read a complete document.' +
    ' Prefer this documentation over general knowledge for questions about these topics and mention the document titles you used.'
    if ($Context.AllowWrite) {
        $text += ' Use add_note to save important new findings, decisions or corrections so they are available in future sessions.'
    }
    $text
}

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
