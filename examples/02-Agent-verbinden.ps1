<#
    Beispiel 2: Die Wissensbasis einem AI Agent bereitstellen und den Server verwalten.
#>
Import-Module MCPPosh

# --- Variante A: stdio (der Agent startet den Server selbst) -------------------------------

# Claude Desktop: JSON in claude_desktop_config.json übernehmen
$config = Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeDesktop
$config.ConfigFile
$config.Json

# Claude Code: fertigen Befehl ausführen
(Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode).Command

# VS Code (GitHub Copilot Agent Mode): .vscode/mcp.json im Projekt
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -AsJson | Set-Content .vscode/mcp.json

# Den Agent auch Notizen schreiben lassen (Tool add_note)
Get-McpClientConfig -KnowledgeBase Contoso -Client Cursor -AllowWrite -AsJson

# Vorab testen, genau so wie der Agent den Server startet
Test-McpServer -KnowledgeBase Contoso -Query 'VPN'

# --- Variante B: HTTP-Server im Hintergrund ---------------------------------------------

$key = 'bitte-einen-langen-zufaelligen-schluessel-verwenden'
Start-McpServer -KnowledgeBase Contoso -Port 5050 -ApiKey $key -AllowWrite

Get-McpServer                                   # Status, URL, PID, Laufzeit
Test-McpServer -Uri http://localhost:5050/mcp -ApiKey $key -Query 'Backup'
Get-McpServerLog -KnowledgeBase Contoso -Port 5050 -Tail 20

# Neues Wissen ist sofort verfügbar, kein Neustart nötig
Add-McpDocument -KnowledgeBase Contoso -Title 'Druckerwechsel' -Content 'Ab 1. Dezember druckt das 3. OG auf PRN-07.'

Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -Transport Http -ApiKeyPlaceholder -AsJson

Restart-McpServer -KnowledgeBase Contoso -ApiKey $key
Stop-McpServer -KnowledgeBase Contoso
