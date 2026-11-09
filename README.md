# MCPPosh

**Deine eigene Dokumentation als MCP-Server für AI Agents, komplett mit PowerShell verwaltet.**

MCPPosh ist ein PowerShell-Modul. Damit baust du eine Wissensbasis aus deinen Dokumenten auf
(Markdown, Word, PDF, HTML/Webseiten, CSV, JSON/YAML/XML, Skripte …) und stellst sie über das
[Model Context Protocol](https://modelcontextprotocol.io) einem AI Agent bereit, etwa Claude
Desktop, Claude Code, GitHub Copilot in VS Code oder Cursor. Der Server läuft lokal oder zentral,
zum Beispiel in Azure.

```powershell
New-McpKnowledgeBase -Name Contoso -Description 'Interne IT-Doku: Runbooks, Architektur, FAQ'
Add-McpDocument -KnowledgeBase Contoso -Path .\docs -Recurse
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeDesktop   # Konfiguration für den Agent
```

## Funktionen

- **Wissen in vielen Formaten hinzufügen**: Dateien, ganze Ordner, Pipeline aus `Get-ChildItem`,
  Webseiten (`-Url`) und Text (`-Content`). Eigene Formate per `Register-McpDocumentConverter`.
- **Lokale Volltextsuche (BM25)**: abschnittsweise, mit leichtem Stemming für Deutsch und Englisch,
  Präfixsuche und Tag-Filtern. Keine API-Keys, keine Cloud-Abhängigkeit.
- **MCP-Server mit zwei Transporten**: *stdio* (der Agent startet den Server) und *Streamable HTTP*
  (Hintergrundprozess oder Container) mit API-Key-Schutz.
- **Verwaltung per PowerShell**: starten, stoppen, neu starten, Status, Logs, End-to-End-Test und
  fertige Client-Konfigurationen.
- **Live-Reload**: Neu hinzugefügte Dokumente sind sofort verfügbar, auch auf laufenden Servern.
- **Optionaler Schreibzugriff**: Mit `-AllowWrite` kann der Agent über `add_note` selbst Wissen ablegen.
- **Zentrales Hosting**: Docker-Image, Bicep-Vorlage für Azure Container Apps + Azure Files und
  `Publish-McpKnowledgeBase` zum Veröffentlichen.

## Voraussetzungen

- **PowerShell 7.2 oder neuer** (Windows, Linux, macOS). Windows PowerShell 5.1 wird nicht unterstützt.
- Optional für PDF: das Modul [PSWritePDF](https://www.powershellgallery.com/packages/PSWritePDF)
  oder `pdftotext` (Poppler), siehe [PDF-Unterstützung](#pdf-unterstützung).
- Optional für Azure: `Az.Storage` (Veröffentlichen), `Az.Resources` + Bicep CLI (Bereitstellen).

## Installation

```powershell
git clone https://github.com/nikq29/MCPPosh.git
Import-Module ./MCPPosh/src/MCPPosh/MCPPosh.psd1
```

Damit `Import-Module MCPPosh` überall funktioniert, kopierst du `src/MCPPosh` in einen Ordner aus
`$env:PSModulePath`, zum Beispiel:

```powershell
Copy-Item ./MCPPosh/src/MCPPosh -Destination (Join-Path ($env:PSModulePath -split [IO.Path]::PathSeparator)[0] 'MCPPosh') -Recurse
```

## Schnellstart

```powershell
# 1. Wissensbasis anlegen. Die Beschreibung erhält der Agent als Anweisung.
New-McpKnowledgeBase -Name Contoso -Description 'Interne IT-Dokumentation von Contoso.'

# 2. Wissen hinzufügen
Add-McpDocument -KnowledgeBase Contoso -Path C:\Doku -Recurse -Tags intern
Add-McpDocument -KnowledgeBase Contoso -Url https://example.com/handbuch.html
Add-McpDocument -KnowledgeBase Contoso -Title 'VPN Fehler 809' -Content 'Firewall-Regel VPN-IKE prüfen.' -Tags vpn

# 3. Suche testen, so wie der Agent sucht
Search-McpDocument -KnowledgeBase Contoso -Query 'VPN bricht ab'

# 4. Agent verbinden (Beispiel Claude Code)
(Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode).Command

# 5. Ende-zu-Ende testen
Test-McpServer -KnowledgeBase Contoso -Query 'VPN'
```

## Wissen hinzufügen

`Add-McpDocument` wandelt alles beim Import in Markdown um und legt einen Suchindex an.
Wird dieselbe Datei oder URL erneut hinzugefügt, aktualisiert das das vorhandene Dokument; ein
Duplikat entsteht nicht. Text aus `-Content` wird über den Titel zugeordnet.

| Format | Endungen | Hinweise |
| --- | --- | --- |
| Markdown | `.md` `.markdown` `.mdx` | Titel und Tags aus Front Matter (`title:`, `tags:`) |
| Text | `.txt` `.log` `.rst` `.adoc` … | unbekannte Textdateien werden als Text gelesen |
| HTML / Web | `.html` `.htm`, `-Url` | Überschriften, Listen, Tabellen, Code und Links bleiben erhalten; Navigation und Skripte werden entfernt |
| Word | `.docx` | reines .NET, kein Office nötig; Überschriften (auch lokalisiert), Listen, Tabellen |
| PDF | `.pdf` | über PSWritePDF oder pdftotext |
| CSV / TSV | `.csv` `.tsv` | wird zur Markdown-Tabelle, Trennzeichen (`,` `;` Tab) wird erkannt |
| JSON / YAML / XML | `.json` `.yaml` `.yml` `.xml` `.config` … | als Codeblock |
| Quellcode | `.ps1` `.py` `.cs` `.js` `.ts` `.sql` `.sh` `.bicep` `.tf` `Dockerfile` … | als Codeblock mit Sprache |

```powershell
Add-McpDocument -Path .\docs -Recurse -Include *.md, *.docx -Exclude *entwurf* -Tags handbuch
Get-ChildItem \\server\wiki -Filter *.html -Recurse | Add-McpDocument -KnowledgeBase Contoso
Add-McpDocument -Url https://learn.microsoft.com/powershell/scripting/overview
Add-McpDocument -Path .\export.dat -Format Text      # Konverter erzwingen
```

### Dokumente pflegen

```powershell
Get-McpDocument -KnowledgeBase Contoso -Tag runbook
Get-McpDocument -KnowledgeBase Contoso -Title '*VPN*' -IncludeContent
Set-McpDocument -KnowledgeBase Contoso -Id vpn-fehler-809-1a2b3c -AddTags netzwerk
Update-McpDocument -KnowledgeBase Contoso -All -RemoveMissing   # geänderte Quellen neu einlesen
Get-McpDocument -KnowledgeBase Contoso -Tag veraltet | Remove-McpDocument
```

### Eigene Formate

```powershell
Register-McpDocumentConverter -Name Email -Extension .eml -ScriptBlock {
    param($Path)
    @{ Title = (Split-Path $Path -LeafBase); Content = Get-Content -LiteralPath $Path -Raw }
}
Get-McpDocumentConverter          # alle Formate und Endungen
```

Der Scriptblock gibt einen Markdown-String oder eine Hashtable mit `Content`, `Title` und `Tags`
zurück. Registrierungen gelten für die aktuelle Sitzung; für eine dauerhafte Nutzung gehören sie
ins Profil. Laufende Server brauchen den Konverter nicht, weil beim Import konvertiert wird.

### PDF-Unterstützung

PDFs werden über ein zusätzliches Werkzeug gelesen. MCPPosh nutzt automatisch, was vorhanden ist:

1. **PSWritePDF** (PowerShell-Modul, `Convert-PDFToText`): `Install-Module PSWritePDF -Scope CurrentUser`
2. **pdftotext** aus Poppler: `winget install oschwartz10612.Poppler`, `brew install poppler` oder `apt install poppler-utils`

> PSWritePDF enthält die Bibliothek iText 7, die unter der AGPL steht. Das ist relevant, wenn du
> sie kommerziell weitergibst.

Nach der Installation liest `Update-McpDocument -All -Force` vorhandene PDFs neu ein.

## Server bereitstellen

### stdio: der Agent startet den Server

AI-Clients starten `pwsh` mit `Start-McpServer -Transport Stdio`. Die passende Konfiguration
erzeugt `Get-McpClientConfig`:

```powershell
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeDesktop     # claude_desktop_config.json
Get-McpClientConfig -KnowledgeBase Contoso -Client ClaudeCode        # .Command = 'claude mcp add ...'
Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -AsJson | Set-Content .vscode/mcp.json
Get-McpClientConfig -KnowledgeBase Contoso -Client Cursor            # ~/.cursor/mcp.json
```

Beispielausgabe für Claude Desktop:

```json
{
  "mcpServers": {
    "mcpposh-contoso": {
      "command": "C:\\Program Files\\PowerShell\\7\\pwsh.exe",
      "args": ["-NoLogo", "-NoProfile", "-NonInteractive", "-Command",
               "Import-Module 'C:\\Tools\\MCPPosh\\MCPPosh.psd1'; Start-McpServer -KnowledgeBase 'Contoso' -Transport Stdio"]
    }
  }
}
```

### HTTP: Server im Hintergrund

```powershell
Start-McpServer -KnowledgeBase Contoso -Port 5050 -ApiKey $key   # http://localhost:5050/mcp
Get-McpServer
Get-McpServerLog -KnowledgeBase Contoso -Port 5050 -Wait
Restart-McpServer -KnowledgeBase Contoso -ApiKey $key
Stop-McpServer -KnowledgeBase Contoso

Get-McpClientConfig -KnowledgeBase Contoso -Client VSCode -Transport Http -ApiKeyPlaceholder
```

- Standardmäßig lauscht der Server nur auf `localhost`. Mit `-ListenAddress '*'` ist er im Netzwerk
  erreichbar; dann ist `-ApiKey` Pflicht. Unter Windows braucht das zusätzlich Adminrechte oder eine
  URL-ACL (`netsh http add urlacl url=http://+:5050/ user=DOMAIN\user`).
- Den API-Key schicken Clients als `Authorization: Bearer <key>` oder `X-API-Key: <key>`. Mehrere
  Keys sind möglich, etwa für eine Rotation. Alternativ setzt du `$env:MCPPOSH_API_KEY`.
- `-Foreground` lässt den Server im aktuellen Fenster laufen (für Container und Fehlersuche).

### Was der Agent bekommt

| MCP-Tool | Zweck |
| --- | --- |
| `search_documentation` | Volltextsuche; liefert die passendsten Abschnitte mit Dokument-ID |
| `get_document` | ganzes Dokument als Markdown, bei langen Dokumenten seitenweise (`offset`) |
| `list_documents` | Dokumente mit Titel, Tags und Kurzbeschreibung (Filter nach Tag) |
| `add_note` | Notiz speichern, nur mit `-AllowWrite` |

Zusätzlich ist jedes Dokument als MCP-Resource `mcpposh://<Wissensbasis>/documents/<id>` verfügbar.
Die Beschreibung der Wissensbasis wird als `instructions` übertragen. Unterstützte
Protokollversionen: 2025-11-25, 2025-06-18, 2025-03-26 und 2024-11-05.

## Zentral hosten (Docker / Azure)

```bash
docker build -f docker/Dockerfile -t mcpposh .
docker run -p 8080:8080 -e MCPPOSH_API_KEY=<key> -e MCPPOSH_KNOWLEDGEBASE=Contoso -v mcpposh-data:/data mcpposh
```

Für Azure liegt in [`deploy/azure`](deploy/azure/README.md) eine Bicep-Vorlage samt `deploy.ps1`.
Sie stellt eine Container App mit HTTPS und API-Key bereit; die Wissensbasis liegt auf Azure Files.
Gepflegt wird lokal, veröffentlicht per PowerShell:

```powershell
./deploy/azure/deploy.ps1 -ResourceGroupName rg-mcpposh -Image ghcr.io/<owner>/mcpposh:latest -KnowledgeBase Contoso -Publish
Publish-McpKnowledgeBase -Name Contoso -StorageAccountName <storage> -ShareName mcpposh -ResourceGroupName rg-mcpposh -Prune
Get-McpServer  -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key
Test-McpServer -Uri https://<app>.azurecontainerapps.io/mcp -ApiKey $key -Query 'VPN'
```

## Cmdlet-Übersicht

| Bereich | Cmdlets |
| --- | --- |
| Wissensbasis | `New-`, `Get-`, `Set-`, `Remove-McpKnowledgeBase`, `Export-`/`Import-McpKnowledgeBase` (ZIP), `Publish-McpKnowledgeBase` (Azure Files) |
| Dokumente | `Add-`, `Get-`, `Set-`, `Update-`, `Remove-McpDocument`, `Search-McpDocument` |
| Formate | `Register-`, `Get-`, `Unregister-McpDocumentConverter` |
| Server | `Start-`, `Stop-`, `Restart-`, `Get-McpServer`, `Test-McpServer`, `Get-McpServerLog` |
| Clients | `Get-McpClientConfig` |

Hilfe zu jedem Cmdlet: `Get-Help Add-McpDocument -Full`. Weitere Beispiele stehen in [`examples`](examples).

## Speicherort und Aufbau

Daten liegen unter `$env:MCPPOSH_HOME`, standardmäßig `~/.mcpposh`:

```
~/.mcpposh/
├── knowledgebases/<Name>/
│   ├── knowledgebase.json   # Name, Beschreibung
│   ├── manifest.json        # Dokumentliste, Revision
│   ├── documents/<id>.md    # normalisierter Inhalt
│   ├── index/<id>.json      # vorberechneter Suchindex (Abschnitte, Termhäufigkeiten)
│   └── logs/                # server-stdio.log, server-<port>.log
└── servers/                 # Status lokal gestarteter HTTP-Server
```

Statt eines Namens akzeptiert `-KnowledgeBase` auch einen Pfad, zum Beispiel auf ein eingebundenes
Netzlaufwerk. Die Wissensbasis `Default` wird bei Bedarf automatisch angelegt.

## Sicherheit

- stdio-Server laufen mit den Rechten des Benutzers, der den Agent startet.
- HTTP-Server lauschen standardmäßig nur auf `localhost` und prüfen den `Origin`-Header (Schutz vor
  DNS-Rebinding). Für andere Adressen ist ein API-Key Pflicht, außer mit `-AllowAnonymous` hinter
  einem authentifizierenden Gateway.
- API-Keys werden nie gespeichert und dem Hintergrundprozess über die Umgebung übergeben, nicht über
  die Kommandozeile. Der Vergleich läuft in konstanter Zeit.
- Schreibzugriff für den Agent (`add_note`) ist standardmäßig aus. Agent-Notizen tragen den Tag
  `agent-note` und lassen sich mit `Get-McpDocument -SourceType Agent` prüfen.
- `-Url` akzeptiert nur `http`/`https`.

## Entwicklung

```powershell
Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser
Invoke-Pester ./tests -Output Detailed
```

Die CI (`.github/workflows/ci.yml`) führt die Tests auf Windows, Linux und macOS aus, ergänzt um
PSScriptAnalyzer, den Bicep-Build und den Docker-Build. `docker.yml` veröffentlicht das Image nach
`ghcr.io/<owner>/mcpposh`.
