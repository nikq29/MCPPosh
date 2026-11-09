<#
    Beispiel 1: Eine Wissensbasis anlegen und mit Wissen in verschiedenen Formaten füllen.
#>
Import-Module MCPPosh   # oder: Import-Module ./src/MCPPosh/MCPPosh.psd1

# Die Beschreibung bekommt der AI Agent als Anweisung. Beschreibe, was die Doku abdeckt.
New-McpKnowledgeBase -Name Contoso -Description 'Interne IT-Dokumentation von Contoso: Runbooks, Architektur, FAQ und Richtlinien.'

# Ganze Ordner importieren (Markdown, Word, HTML, PDF, CSV, JSON, YAML, Skripte ...)
Add-McpDocument -KnowledgeBase Contoso -Path C:\Doku\Runbooks -Recurse -Tags runbook
Add-McpDocument -KnowledgeBase Contoso -Path C:\Doku\Handbuecher -Include *.docx, *.pdf -Recurse -Tags handbuch

# Per Pipeline, z. B. nur kürzlich geänderte Dateien
Get-ChildItem C:\Doku\Wiki -Recurse -File |
    Where-Object LastWriteTime -GT (Get-Date).AddDays(-7) |
    Add-McpDocument -KnowledgeBase Contoso

# Webseiten
Add-McpDocument -KnowledgeBase Contoso -Url 'https://learn.microsoft.com/powershell/scripting/overview' -Tags powershell

# Schnell eine Notiz festhalten (gleicher Titel = Aktualisierung)
Add-McpDocument -KnowledgeBase Contoso -Title 'VPN: Fehler 809' -Tags vpn, runbook -Content @'
# VPN: Fehler 809

Ursache: UDP 500/4500 wird von der Firewall blockiert.
Lösung: `Restart-Service vpnagent` und die Firewall-Regel "VPN-IKE" prüfen.
'@

# Eigene Formate nachrüsten, z. B. E-Mails (.eml)
Register-McpDocumentConverter -Name Email -Extension .eml -ScriptBlock {
    param($Path)
    $raw = Get-Content -LiteralPath $Path -Raw
    $subject = ([regex]::Match($raw, '(?m)^Subject:\s*(.+)$')).Groups[1].Value
    @{ Title = $subject; Content = "# $subject`n`n" + ($raw -split "`r?`n`r?`n", 2)[1] }
}
Add-McpDocument -KnowledgeBase Contoso -Path C:\Doku\Mails -Include *.eml -Recurse -Tags mail

# Prüfen, was der Agent finden wird
Search-McpDocument -KnowledgeBase Contoso -Query 'VPN Verbindung bricht ab' | Format-List Score, Title, Heading, Snippet

# Pflege
Get-McpDocument -KnowledgeBase Contoso -Tag runbook | Format-Table Id, Title, Updated
Update-McpDocument -KnowledgeBase Contoso -All -RemoveMissing   # geänderte Quelldateien neu einlesen
Get-McpDocument -KnowledgeBase Contoso -Title '*veraltet*' | Remove-McpDocument

# Sicherung
Export-McpKnowledgeBase -Name Contoso -DestinationPath .\contoso-backup.zip -Force
