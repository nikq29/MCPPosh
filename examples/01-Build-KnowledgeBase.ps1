<#
    Example 1: Create a knowledge base and fill it with knowledge in different formats.
#>
Import-Module MCPPosh   # Install-PSResource MCPPosh, or ./build.ps1 -Tasks build and import from output/module

# The description is sent to the AI agent as instructions. Describe what the documentation covers.
New-McpKnowledgeBase -Name Contoso -Description 'Internal IT documentation of Contoso: runbooks, architecture, FAQ and policies.'

# Import whole folders (Markdown, Word, HTML, PDF, CSV, JSON, YAML, scripts ...)
Add-McpDocument -KnowledgeBase Contoso -Path C:\Docs\Runbooks -Recurse -Tags runbook
Add-McpDocument -KnowledgeBase Contoso -Path C:\Docs\Manuals -Include *.docx, *.pdf -Recurse -Tags manual

# Pipeline input, for example only recently changed files
Get-ChildItem C:\Docs\Wiki -Recurse -File |
    Where-Object LastWriteTime -GT (Get-Date).AddDays(-7) |
    Add-McpDocument -KnowledgeBase Contoso

# Web pages
Add-McpDocument -KnowledgeBase Contoso -Url 'https://learn.microsoft.com/powershell/scripting/overview' -Tags powershell

# Write down a quick note (the same title updates the note)
Add-McpDocument -KnowledgeBase Contoso -Title 'VPN: error 809' -Tags vpn, runbook -Content @'
# VPN: error 809

Cause: UDP 500/4500 is blocked by the firewall.
Fix: run `Restart-Service vpnagent` and check the firewall rule "VPN-IKE".
'@

# Add your own formats, for example e-mails (.eml)
Register-McpDocumentConverter -Name Email -Extension .eml -ScriptBlock {
    param($Path)
    $raw = Get-Content -LiteralPath $Path -Raw
    $subject = ([regex]::Match($raw, '(?m)^Subject:\s*(.+)$')).Groups[1].Value
    @{ Title = $subject; Content = "# $subject`n`n" + ($raw -split "`r?`n`r?`n", 2)[1] }
}
Add-McpDocument -KnowledgeBase Contoso -Path C:\Docs\Mails -Include *.eml -Recurse -Tags mail

# Check what the agent will find
Search-McpDocument -KnowledgeBase Contoso -Query 'vpn connection drops' | Format-List Score, Title, Heading, Snippet

# Maintenance
Get-McpDocument -KnowledgeBase Contoso -Tag runbook | Format-Table Id, Title, Updated
Update-McpDocument -KnowledgeBase Contoso -All -RemoveMissing   # re-import changed source files
Get-McpDocument -KnowledgeBase Contoso -Title '*obsolete*' | Remove-McpDocument

# Backup
Export-McpKnowledgeBase -Name Contoso -DestinationPath .\contoso-backup.zip -Force
