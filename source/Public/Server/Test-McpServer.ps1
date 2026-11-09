function Test-McpServer {
    <#
    .SYNOPSIS
        Checks an MCP server end-to-end like an AI client would.

    .DESCRIPTION
        Performs the MCP handshake (initialize), lists the tools, counts the documents and,
        with -Query, runs a search. Works against HTTP servers (-Uri, local or e.g. in Azure)
        and against the stdio server of a local knowledge base (-KnowledgeBase), which is
        exactly what AI clients start.

    .PARAMETER Uri
        Base URL or MCP endpoint of an HTTP server, e.g. http://localhost:5050/mcp.

    .PARAMETER ApiKey
        API key for the HTTP server.

    .PARAMETER KnowledgeBase
        Test the stdio server for this knowledge base.

    .PARAMETER Query
        Optional search query to run with the search_documentation tool.

    .PARAMETER TimeoutSeconds
        Seconds to wait for each response of the server before the test fails with a timeout.

    .EXAMPLE
        Test-McpServer -KnowledgeBase Contoso -Query 'VPN'

    .EXAMPLE
        Test-McpServer -Uri https://mcpposh.azurecontainerapps.io -ApiKey $key
    #>
    [CmdletBinding(DefaultParameterSetName = 'Http')]
    [OutputType('MCPPosh.TestResult')]
    param(
        [Parameter(Mandatory, Position = 0, ParameterSetName = 'Http', ValueFromPipelineByPropertyName)]
        [Alias('Url')]
        [uri] $Uri,

        [Parameter(ParameterSetName = 'Http')]
        [string] $ApiKey,

        [Parameter(Mandatory, ParameterSetName = 'Stdio')]
        [string] $KnowledgeBase,

        [string] $Query,

        [ValidateRange(1, 600)]
        [int] $TimeoutSeconds = 30
    )

    process {
        $watch = [System.Diagnostics.Stopwatch]::StartNew()
        $requestTimeout = $TimeoutSeconds
        $result = [ordered]@{
            PSTypeName      = 'MCPPosh.TestResult'
            Target          = $null
            Transport       = $PSCmdlet.ParameterSetName
            Success         = $false
            ProtocolVersion = $null
            ServerName      = $null
            ServerVersion   = $null
            Instructions    = $null
            Tools           = [string[]]@()
            Documents       = $null
            SearchResults   = $null
            TopResult       = $null
            ElapsedMs       = 0
            Error           = $null
        }

        $client = $null
        try {
            if ($PSCmdlet.ParameterSetName -eq 'Http') {
                $endpoint = Resolve-McpEndpointUri -Uri $Uri
                $result.Target = $endpoint.AbsoluteUri
                $headers = @{}
                if ($ApiKey) { $headers['Authorization'] = "Bearer $ApiKey" }
                $send = { param($Message) Invoke-McpHttpRpc -Endpoint $endpoint -Message $Message -Headers $headers -TimeoutSeconds $requestTimeout }
            }
            else {
                $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase
                $result.Target = "stdio: $($kb.Name)"
                $client = Start-McpStdioClient -KbPath $kb.Path
                $send = { param($Message) Invoke-McpStdioRpc -Client $client -Message $Message -TimeoutSeconds $requestTimeout }
            }

            $requestId = 0
            $call = {
                param([string] $Method, [System.Collections.IDictionary] $Params)
                $requestId++
                $response = & $send ([ordered]@{ jsonrpc = '2.0'; id = $requestId; method = $Method; params = $Params })
                if ($null -eq $response) { throw "No response to '$Method'." }
                if ($response.Contains('error')) { throw "'$Method' failed: $($response['error']['message']) (code $($response['error']['code']))" }
                $response['result']
            }

            $init = . $call 'initialize' ([ordered]@{
                    protocolVersion = $script:McpSupportedProtocolVersions[0]
                    capabilities    = [ordered]@{}
                    clientInfo      = [ordered]@{ name = 'MCPPosh Test-McpServer'; version = $script:ModuleVersion }
                })
            $result.ProtocolVersion = [string]$init['protocolVersion']
            $result.ServerName = [string]$init['serverInfo']['name']
            $result.ServerVersion = [string]$init['serverInfo']['version']
            $result.Instructions = [string]$init['instructions']
            $null = & $send ([ordered]@{ jsonrpc = '2.0'; method = 'notifications/initialized' })

            $tools = . $call 'tools/list' ([ordered]@{})
            $toolNames = [string[]]@($tools['tools'] | ForEach-Object { $_['name'] })
            $result.Tools = $toolNames

            if ($toolNames -contains 'list_documents') {
                $list = . $call 'tools/call' ([ordered]@{ name = 'list_documents'; arguments = [ordered]@{ limit = 1 } })
                if ($list['structuredContent']) { $result.Documents = [int]$list['structuredContent']['total'] }
            }

            if ($Query) {
                $search = . $call 'tools/call' ([ordered]@{ name = 'search_documentation'; arguments = [ordered]@{ query = $Query; limit = 5 } })
                if ($search['isError']) { throw "search_documentation failed: $($search['content'][0]['text'])" }
                $hits = @()
                if ($search['structuredContent']) { $hits = @($search['structuredContent']['results']) }
                $result.SearchResults = $hits.Count
                if ($hits.Count -gt 0) {
                    $top = $hits[0]
                    $heading = [string]$top['heading']
                    $title = [string]$top['title']
                    $result.TopResult = if (-not $heading -or $heading -eq $title -or $heading.StartsWith("$title > ")) { if ($heading) { $heading } else { $title } } else { "$title > $heading" }
                }
            }
            $result.Success = $true
        }
        catch {
            $result.Error = $_.Exception.Message
        }
        finally {
            if ($client) { Stop-McpStdioClient -Client $client }
            $result.ElapsedMs = $watch.ElapsedMilliseconds
        }
        [pscustomobject]$result
    }
}
