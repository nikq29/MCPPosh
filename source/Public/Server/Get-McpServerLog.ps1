function Get-McpServerLog {
    <#
    .SYNOPSIS
        Shows the log of an MCP server.
    .DESCRIPTION
        Each knowledge base keeps its server logs in <knowledge base>/logs: server-<port>.log for
        HTTP servers and server-stdio.log for servers started by AI clients over stdio.
    .PARAMETER KnowledgeBase
        Knowledge base whose log to show.
    .PARAMETER Port
        Show the log of the HTTP server on this port.
    .PARAMETER Stdio
        Show the log of stdio servers (started by AI clients).
    .PARAMETER Tail
        Number of lines from the end of the log.
    .PARAMETER Wait
        Keep following the log (like tail -f) until Ctrl+C.
    .EXAMPLE
        Get-McpServerLog -KnowledgeBase Contoso -Tail 20
    .EXAMPLE
        Get-McpServerLog -KnowledgeBase Contoso -Stdio -Wait
    #>
    [CmdletBinding(DefaultParameterSetName = 'Latest')]
    [OutputType([string])]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [string] $KnowledgeBase = 'Default',

        [Parameter(ParameterSetName = 'Port', ValueFromPipelineByPropertyName)]
        [int] $Port,

        [Parameter(ParameterSetName = 'Stdio')]
        [switch] $Stdio,

        [ValidateRange(1, 100000)]
        [int] $Tail = 50,

        [switch] $Wait
    )

    process {
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase
        $logDirectory = Join-Path -Path $kb.Path -ChildPath 'logs'
        $logFile = if ($Stdio) {
            Join-Path -Path $logDirectory -ChildPath 'server-stdio.log'
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Port') {
            Join-Path -Path $logDirectory -ChildPath "server-$Port.log"
        }
        else {
            Get-ChildItem -LiteralPath $logDirectory -Filter 'server-*.log' -File -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch '\.(stdout|stderr)\.log$' } |
                Sort-Object -Property LastWriteTimeUtc -Descending |
                Select-Object -First 1 -ExpandProperty FullName
        }

        if (-not $logFile -or -not (Test-Path -LiteralPath $logFile)) {
            Write-Error -Message "No server log found for knowledge base '$($kb.Name)' in $logDirectory." -Category ObjectNotFound
            return
        }
        Get-Content -LiteralPath $logFile -Tail $Tail -Wait:$Wait -Encoding utf8
    }
}
