function Get-McpClientConfig {
    <#
    .SYNOPSIS
        Generates the configuration to connect an AI client to an MCPPosh server.

    .DESCRIPTION
        Produces the JSON snippet (and for Claude Code the 'claude mcp add' command) for:
          ClaudeDesktop  claude_desktop_config.json ("mcpServers")
          ClaudeCode     .mcp.json or 'claude mcp add'
          VSCode         .vscode/mcp.json ("servers")
          Cursor         ~/.cursor/mcp.json ("mcpServers")
          Generic        the common "mcpServers" format used by most other clients

        With -Transport Stdio (default) the client starts the server itself via pwsh. With
        -Transport Http the client connects to a running server (local or hosted, e.g. Azure).

    .PARAMETER KnowledgeBase
        Knowledge base to serve (stdio) or to name the server after.

    .PARAMETER Client
        AI client to create the configuration for: ClaudeDesktop, ClaudeCode, VSCode, Cursor or Generic.

    .PARAMETER Transport
        Stdio (client starts the server) or Http (client connects to -Uri).

    .PARAMETER Uri
        MCP endpoint for -Transport Http. Defaults to the local server of the knowledge base.

    .PARAMETER ApiKey
        API key for -Transport Http. Use -ApiKeyPlaceholder to reference an environment variable instead.

    .PARAMETER ApiKeyPlaceholder
        Writes an environment variable reference such as ${env:MCPPOSH_API_KEY} instead of the key.

    .PARAMETER ServerName
        Name of the server entry. Defaults to 'mcpposh-<knowledge base>'.

    .PARAMETER AllowWrite
        Stdio only: lets the agent add notes (add_note tool).

    .PARAMETER UseModuleName
        Stdio only: import the module by name instead of by path. This is the default when MCPPosh is
        installed in a standard module folder (for example with Install-PSResource MCPPosh).

    .PARAMETER AsJson
        Return only the JSON text.

    .EXAMPLE
        Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeDesktop

    .EXAMPLE
        (Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode).Command

    .EXAMPLE
        Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -Transport Http -Uri https://mcpposh.azurecontainerapps.io/mcp -ApiKeyPlaceholder
    #>
    [CmdletBinding()]
    [OutputType('MCPPosh.ClientConfig', [string])]
    param(
        [Parameter(Position = 0)]
        [string] $KnowledgeBase = 'Default',

        [Parameter(Position = 1)]
        [ValidateSet('ClaudeDesktop', 'ClaudeCode', 'VSCode', 'Cursor', 'Generic')]
        [string] $Client = 'Generic',

        [ValidateSet('Stdio', 'Http')]
        [string] $Transport = 'Stdio',

        [uri] $Uri,

        [string] $ApiKey,

        [switch] $ApiKeyPlaceholder,

        [string] $ServerName,

        [switch] $AllowWrite,

        [switch] $UseModuleName,

        [switch] $AsJson
    )

    $kb = $null
    if ($Transport -eq 'Stdio' -or -not $Uri) {
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase -CreateIfMissing:($KnowledgeBase -eq 'Default')
    }
    $kbName = if ($kb) { $kb.Name } else { $KnowledgeBase }
    if (-not $ServerName) { $ServerName = 'mcpposh-' + (ConvertTo-McpSlug -Text $kbName) }

    $entry = [ordered]@{}
    $command = $null
    $notes = [System.Collections.Generic.List[string]]::new()

    if ($Transport -eq 'Stdio') {
        # A module installed with Install-PSResource/Install-Module lives in a standard module folder and is
        # imported by name, so the configuration keeps working after module updates.
        $standardModuleRoots = @(
            (Join-Path -Path $PSHOME -ChildPath 'Modules')
            $(if ($IsWindows) { Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath 'PowerShell/Modules' } else { Join-Path -Path $HOME -ChildPath '.local/share/powershell/Modules' })
            $(if ($IsWindows) { Join-Path -Path $env:ProgramFiles -ChildPath 'PowerShell/Modules' } else { '/usr/local/share/powershell/Modules' })
        ) | ForEach-Object { [System.IO.Path]::GetFullPath($_).TrimEnd('/', '\') + [System.IO.Path]::DirectorySeparatorChar }
        $installedFromGallery = @($standardModuleRoots | Where-Object { $script:ModuleManifestPath.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
        $moduleReference = if ($UseModuleName -or $installedFromGallery) { 'MCPPosh' } else { "'" + $script:ModuleManifestPath.Replace("'", "''") + "'" }
        $kbReference = if (Test-McpLooksLikePath -Value $KnowledgeBase) { $kb.Path } else { $kb.Name }
        $serverCommand = "Import-Module $moduleReference; Start-McpServer -KnowledgeBase '$($kbReference.Replace("'", "''"))' -Transport Stdio" + $(if ($AllowWrite) { ' -AllowWrite' } else { '' })
        $pwsh = Get-McpPwshPath
        $arguments = @('-NoLogo', '-NoProfile', '-NonInteractive', '-Command', $serverCommand)

        if ($Client -in 'VSCode', 'ClaudeCode') { $entry['type'] = 'stdio' }
        $entry['command'] = $pwsh
        $entry['args'] = $arguments
        if ($env:MCPPOSH_HOME) { $entry['env'] = [ordered]@{ MCPPOSH_HOME = $env:MCPPOSH_HOME } }

        if ($Client -eq 'ClaudeCode') {
            $envArgument = if ($env:MCPPOSH_HOME) { " -e MCPPOSH_HOME=$(ConvertTo-McpShellArgument $env:MCPPOSH_HOME)" } else { '' }
            $command = "claude mcp add$envArgument $ServerName -- $(ConvertTo-McpShellArgument $pwsh) -NoLogo -NoProfile -NonInteractive -Command $(ConvertTo-McpShellArgument $serverCommand)"
        }
    }
    else {
        if (-not $Uri) {
            $local = Get-McpServerState | Where-Object { $_.kbPath -eq $kb.Path -and $_.Status -eq 'Running' } | Select-Object -First 1
            if (-not $local) {
                throw "No running HTTP server found for knowledge base '$kbName'. Start one with Start-McpServer or pass -Uri."
            }
            $Uri = [string]$local.url
        }
        $endpoint = (Resolve-McpEndpointUri -Uri $Uri).AbsoluteUri

        $keyValue = $null
        if ($ApiKeyPlaceholder) {
            $keyValue = switch ($Client) {
                'VSCode' { '${input:mcpposh-api-key}' }
                'ClaudeCode' { '${MCPPOSH_API_KEY}' }
                'Cursor' { '${env:MCPPOSH_API_KEY}' }
                default { '${MCPPOSH_API_KEY}' }
            }
        }
        elseif ($ApiKey) {
            $keyValue = $ApiKey
            $notes.Add('The configuration contains the API key in plain text. Consider -ApiKeyPlaceholder.')
        }

        switch ($Client) {
            'ClaudeDesktop' {
                # Claude Desktop connects to remote servers through the mcp-remote bridge (Node.js).
                $entry['command'] = 'npx'
                $bridgeArgs = [System.Collections.Generic.List[string]]::new()
                foreach ($a in '-y', 'mcp-remote', $endpoint) { $bridgeArgs.Add($a) }
                if ($keyValue) {
                    $bridgeArgs.Add('--header')
                    $bridgeArgs.Add('Authorization:${MCPPOSH_AUTH_HEADER}')
                    $headerValue = if ($ApiKeyPlaceholder) { 'Bearer <your-api-key>' } else { "Bearer $keyValue" }
                    $entry['env'] = [ordered]@{ MCPPOSH_AUTH_HEADER = $headerValue }
                }
                $entry['args'] = $bridgeArgs.ToArray()
                $notes.Add('Requires Node.js (npx). Alternatively add the server as a custom connector in Claude Desktop (Settings > Connectors).')
            }
            'ClaudeCode' {
                $entry['type'] = 'http'
                $entry['url'] = $endpoint
                if ($keyValue) { $entry['headers'] = [ordered]@{ Authorization = "Bearer $keyValue" } }
                $headerArgument = if ($keyValue) { ' --header ' + (ConvertTo-McpShellArgument "Authorization: Bearer $keyValue") } else { '' }
                $command = "claude mcp add --transport http $ServerName $endpoint$headerArgument"
            }
            'VSCode' {
                $entry['type'] = 'http'
                $entry['url'] = $endpoint
                if ($keyValue) { $entry['headers'] = [ordered]@{ Authorization = "Bearer $keyValue" } }
            }
            default {
                $entry['url'] = $endpoint
                if ($keyValue) { $entry['headers'] = [ordered]@{ Authorization = "Bearer $keyValue" } }
            }
        }
    }

    $root = if ($Client -eq 'VSCode') {
        $config = [ordered]@{ servers = [ordered]@{ $ServerName = $entry } }
        if ($Transport -eq 'Http' -and $ApiKeyPlaceholder) {
            $config = [ordered]@{
                inputs  = @([ordered]@{ type = 'promptString'; id = 'mcpposh-api-key'; description = 'MCPPosh API key'; password = $true })
                servers = $config.servers
            }
        }
        $config
    }
    else {
        [ordered]@{ mcpServers = [ordered]@{ $ServerName = $entry } }
    }
    $json = ConvertTo-McpJson -InputObject $root

    if ($AsJson) { return $json }

    [pscustomobject]@{
        PSTypeName = 'MCPPosh.ClientConfig'
        Client     = $Client
        Transport  = $Transport
        ServerName = $ServerName
        ConfigFile = Get-McpClientConfigPath -Client $Client
        Json       = $json
        Command    = $command
        Notes      = $notes.ToArray()
    }
}
