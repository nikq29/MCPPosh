---
external help file: MCPPosh-help.xml
GeneratedBy: Sampler update_help_source task
Module Name: MCPPosh
online version: https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpClientConfig.md
schema: 2.0.0
---

# Get-McpClientConfig

## SYNOPSIS
Generates the configuration to connect an AI client to an MCPPosh server.

## SYNTAX

```
Get-McpClientConfig [[-KnowledgeBase] <String>] [[-Client] <String>] [-Transport <String>] [-Uri <Uri>]
 [-ApiKey <String>] [-ApiKeyPlaceholder] [-ServerName <String>] [-AllowWrite] [-UseModuleName] [-AsJson]
 [<CommonParameters>]
```

## DESCRIPTION
Produces the JSON snippet (and for Claude Code the 'claude mcp add' command) for:
  ClaudeDesktop  claude_desktop_config.json ("mcpServers")
  ClaudeCode     .mcp.json or 'claude mcp add'
  VSCode         .vscode/mcp.json ("servers")
  Cursor         ~/.cursor/mcp.json ("mcpServers")
  Generic        the common "mcpServers" format used by most other clients

With -Transport Stdio (default) the client starts the server itself via pwsh.
With
-Transport Http the client connects to a running server (local or hosted, e.g.
Azure).

## EXAMPLES

### EXAMPLE 1
```
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeDesktop
```

Returns the configuration entry for Claude Desktop.
Copy the Json property into the file shown in ConfigFile; Claude Desktop then starts the stdio server itself.

### EXAMPLE 2
```
(Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode).Command
```

Returns a claude mcp add command that registers the stdio server in Claude Code.

### EXAMPLE 3
```
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -Transport Http -Uri https://mcpposh.azurecontainerapps.io/mcp -ApiKeyPlaceholder -AsJson
```

Returns a .vscode/mcp.json for a hosted HTTP server.
VS Code prompts for the API key instead of storing it in the file.

## PARAMETERS

### -KnowledgeBase
Knowledge base to serve (stdio) or to name the server after.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: Default
Accept pipeline input: False
Accept wildcard characters: False
```

### -Client
AI client to create the configuration for: ClaudeDesktop, ClaudeCode, VSCode, Cursor or Generic.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: Generic
Accept pipeline input: False
Accept wildcard characters: False
```

### -Transport
Stdio (client starts the server) or Http (client connects to -Uri).

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: Stdio
Accept pipeline input: False
Accept wildcard characters: False
```

### -Uri
MCP endpoint for -Transport Http.
Defaults to the local server of the knowledge base.

```yaml
Type: Uri
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiKey
API key for -Transport Http.
Use -ApiKeyPlaceholder to reference an environment variable instead.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -ApiKeyPlaceholder
Writes an environment variable reference such as ${env:MCPPOSH_API_KEY} instead of the key.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ServerName
Name of the server entry.
Defaults to 'mcpposh-\<knowledge base\>'.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -AllowWrite
Stdio only: lets the agent add notes (add_note tool).

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -UseModuleName
Stdio only: import the module by name instead of by path.
This is the default when MCPPosh is
installed in a standard module folder (for example with Install-PSResource MCPPosh).

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -AsJson
Return only the JSON text.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

### None. You cannot pipe objects to this cmdlet.
## OUTPUTS

### MCPPosh.ClientConfig: Client, Transport, ServerName, ConfigFile, Json, Command (Claude Code) and Notes. With -AsJson: System.String.
## NOTES

## RELATED LINKS

[https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpClientConfig.md](https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpClientConfig.md)

[Start-McpServer]()

[Test-McpServer]()

