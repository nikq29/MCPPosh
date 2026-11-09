BeforeAll {
    . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    $script:TestHome = Initialize-McpTestEnvironment -Name converters
    $script:Files = Join-Path $script:TestHome 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
}

AfterAll {
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Markdown converter' {
    It 'reads front matter title and tags and strips the front matter' {
        $path = Join-Path $script:Files 'fm.md'
        Set-Content -Path $path -Value "---`ntitle: Mein Titel`ntags:`n  - eins`n  - zwei`n---`n# Überschrift`n`nText"
        $result = InModuleScope MCPPosh -Parameters @{ Path = $path } { param($Path) ConvertTo-McpMarkdown -Path $Path }
        $result.Title | Should -Be 'Mein Titel'
        $result.Tags | Should -Be @('eins', 'zwei')
        $result.Content | Should -Not -Match 'title:'
        $result.Format | Should -Be 'Markdown'
    }

    It 'uses the first heading as title' {
        $path = Join-Path $script:Files 'heading.md'
        Set-Content -Path $path -Value "Intro`n`n# Echter Titel`n`nmehr"
        $result = InModuleScope MCPPosh -Parameters @{ Path = $path } { param($Path) ConvertTo-McpMarkdown -Path $Path }
        $result.Title | Should -Be 'Echter Titel'
    }
}

Describe 'HTML converter' {
    BeforeAll {
        $script:Html = @'
<html><head><title>VPN Hilfe</title><style>body{}</style></head>
<body><nav><a href="/">Home</a></nav>
<main>
  <h1>VPN Troubleshooting</h1>
  <p>Wenn die <b>VPN</b> Verbindung   abbricht, <em>starte</em> den Dienst neu &amp; prüfe <code>vpnagent</code>:</p>
  <pre><code class="language-powershell">Restart-Service vpnagent
Get-Service vpnagent</code></pre>
  <ul><li>Schritt eins</li><li>Schritt zwei</li></ul>
  <table><tr><th>Code</th><th>Bedeutung</th></tr><tr><td>809</td><td>Port blockiert</td></tr></table>
  <p>Siehe <a href="details.html">Details</a>.</p>
  <script>alert(1)</script>
</main></body></html>
'@
        $script:Converted = InModuleScope MCPPosh -Parameters @{ Html = $script:Html } {
            param($Html) ConvertFrom-McpHtml -Html $Html -BaseUrl 'https://docs.example.com/vpn/index.html'
        }
    }

    It 'extracts the title' {
        $script:Converted.Title | Should -Be 'VPN Hilfe'
    }

    It 'converts headings, emphasis, inline code and entities' {
        $script:Converted.Content | Should -Match '(?m)^# VPN Troubleshooting$'
        $script:Converted.Content | Should -Match '\*\*VPN\*\* Verbindung abbricht, \*starte\* den Dienst neu & prüfe `vpnagent`:'
    }

    It 'keeps preformatted code with its language' {
        $script:Converted.Content | Should -Match '(?s)```powershell\nRestart-Service vpnagent\nGet-Service vpnagent\n```'
    }

    It 'converts lists and tables' {
        $script:Converted.Content | Should -Match '(?m)^- Schritt eins\n- Schritt zwei$'
        $script:Converted.Content | Should -Match '(?m)^\| Code \| Bedeutung \|$'
        $script:Converted.Content | Should -Match '(?m)^\| 809 \| Port blockiert \|$'
    }

    It 'resolves relative links against the base URL' {
        $script:Converted.Content | Should -Match '\[Details\]\(https://docs\.example\.com/vpn/details\.html\)'
    }

    It 'drops scripts, styles and navigation' {
        $script:Converted.Content | Should -Not -Match 'alert|body\{\}|Home'
    }
}

Describe 'Word (.docx) converter' {
    BeforeAll {
        $script:DocxPath = Join-Path $script:Files 'handbuch.docx'
        New-McpTestDocx -Path $script:DocxPath
        $script:Docx = InModuleScope MCPPosh -Parameters @{ Path = $script:DocxPath } { param($Path) ConvertTo-McpMarkdown -Path $Path }
    }

    It 'uses the document title from the core properties' {
        $script:Docx.Title | Should -Be 'Handbuch Notfallbetrieb'
        $script:Docx.Format | Should -Be 'Docx'
    }

    It 'maps localized heading styles to Markdown headings' {
        $script:Docx.Content | Should -Match '(?m)^# Betriebshandbuch$'
        $script:Docx.Content | Should -Match '(?m)^## Eskalation$'
    }

    It 'joins runs within a paragraph' {
        $script:Docx.Content | Should -Match 'Dieses Handbuch beschreibt den Notfallbetrieb\.'
    }

    It 'converts lists with indentation and tables' {
        $script:Docx.Content | Should -Match '(?m)^- Leitstelle anrufen$'
        $script:Docx.Content | Should -Match '(?m)^  - Ticket erstellen$'
        $script:Docx.Content | Should -Match '(?m)^\| Stufe \| Kontakt \|$'
        $script:Docx.Content | Should -Match '\| 1 \| Servicedesk \\\| 24/7 \|'
    }
}

Describe 'Data and code converters' {
    It 'converts CSV with semicolons to a Markdown table' {
        $path = Join-Path $script:Files 'kontakte.csv'
        Set-Content -Path $path -Value "Name;Rolle`nAnna;Admin`nBen;Support"
        $result = InModuleScope MCPPosh -Parameters @{ Path = $path } { param($Path) ConvertTo-McpMarkdown -Path $Path }
        $result.Format | Should -Be 'Csv'
        $result.Content | Should -Match '(?m)^\| Name \| Rolle \|$'
        $result.Content | Should -Match '(?m)^\| Ben \| Support \|$'
    }

    It 'wraps JSON in a fenced code block' {
        $path = Join-Path $script:Files 'settings.json'
        Set-Content -Path $path -Value '{ "port": 8080 }'
        $result = InModuleScope MCPPosh -Parameters @{ Path = $path } { param($Path) ConvertTo-McpMarkdown -Path $Path }
        $result.Format | Should -Be 'Json'
        $result.Content | Should -Match '(?s)```json\n\{ "port": 8080 \}\n```'
    }

    It 'wraps PowerShell scripts in a fenced code block' {
        $path = Join-Path $script:Files 'deploy.ps1'
        Set-Content -Path $path -Value 'Write-Output "deploy"'
        $result = InModuleScope MCPPosh -Parameters @{ Path = $path } { param($Path) ConvertTo-McpMarkdown -Path $Path }
        $result.Format | Should -Be 'Code'
        $result.Title | Should -Be 'deploy.ps1'
        $result.Content | Should -Match '```powershell'
    }

    It 'uses a longer fence when the code contains backtick fences' {
        $path = Join-Path $script:Files 'readme.py'
        Set-Content -Path $path -Value "doc = '''`n``````python`nx`n``````'''"
        $result = InModuleScope MCPPosh -Parameters @{ Path = $path } { param($Path) ConvertTo-McpMarkdown -Path $Path }
        $result.Content | Should -Match '(?m)^````python$'
    }

    It 'recognizes well-known file names such as Dockerfile' {
        $path = Join-Path $script:Files 'Dockerfile'
        Set-Content -Path $path -Value 'FROM mcr.microsoft.com/powershell'
        $result = InModuleScope MCPPosh -Parameters @{ Path = $path } { param($Path) ConvertTo-McpMarkdown -Path $Path }
        $result.Content | Should -Match '```dockerfile'
    }

    It 'falls back to text for unknown text files and rejects binary files' {
        $text = Join-Path $script:Files 'notes.unknownext'
        Set-Content -Path $text -Value 'plain text'
        $binary = Join-Path $script:Files 'blob.bin'
        [System.IO.File]::WriteAllBytes($binary, [byte[]](0, 1, 2, 0, 5))
        (InModuleScope MCPPosh -Parameters @{ Path = $text } { param($Path) ConvertTo-McpMarkdown -Path $Path }).Format | Should -Be 'Text'
        { InModuleScope MCPPosh -Parameters @{ Path = $binary } { param($Path) ConvertTo-McpMarkdown -Path $Path } } | Should -Throw '*No converter*'
    }
}

Describe 'PDF converter' {
    It 'uses the PDF text extraction and turns form feeds into paragraph breaks' {
        $path = Join-Path $script:Files 'manual.pdf'
        Set-Content -Path $path -Value '%PDF-1.4 fake'
        InModuleScope MCPPosh -Parameters @{ Path = $path } {
            param($Path)
            Mock Invoke-McpPdfTextExtraction { "Seite eins`fSeite zwei" }
            $result = ConvertTo-McpMarkdown -Path $Path
            $result.Format | Should -Be 'Pdf'
            $result.Title | Should -Be 'manual'
            $result.Content | Should -Be "Seite eins`n`nSeite zwei"
        }
    }

    It 'explains how to enable PDF support when no extractor is available' {
        $path = Join-Path $script:Files 'manual2.pdf'
        Set-Content -Path $path -Value '%PDF-1.4 fake'
        InModuleScope MCPPosh -Parameters @{ Path = $path } {
            param($Path)
            Mock Get-Module { $null } -ParameterFilter { $Name -eq 'PSWritePDF' }
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'pdftotext' }
            { Invoke-McpPdfTextExtraction -Path $Path } | Should -Throw '*PSWritePDF*pdftotext*'
        }
    }
}

Describe 'Custom converters' {
    AfterEach {
        Get-McpDocumentConverter | Where-Object { -not $_.Builtin } | Unregister-McpDocumentConverter
    }

    It 'registers, uses and unregisters a custom converter' {
        Register-McpDocumentConverter -Name Email -Extension 'eml' -ScriptBlock {
            param($Path)
            @{ Content = "# Mail`n`n" + (Get-Content -LiteralPath $Path -Raw); Title = 'Eine Mail'; Tags = 'mail' }
        } | Out-Null
        $path = Join-Path $script:Files 'message.eml'
        Set-Content -Path $path -Value 'Hallo Welt'

        (Get-McpDocumentConverter -Extension .eml).Name | Should -Be 'Email'
        $result = InModuleScope MCPPosh -Parameters @{ Path = $path } { param($Path) ConvertTo-McpMarkdown -Path $Path }
        $result.Title | Should -Be 'Eine Mail'
        $result.Format | Should -Be 'Email'
        $result.Tags | Should -Be @('mail')

        Unregister-McpDocumentConverter -Name Email
        Get-McpDocumentConverter -Name Email | Should -BeNullOrEmpty
    }

    It 'lets custom converters override built-in extensions' {
        Register-McpDocumentConverter -Name UpperText -Extension .txt -ScriptBlock { param($Path) (Get-Content -LiteralPath $Path -Raw).ToUpperInvariant() } | Out-Null
        $path = Join-Path $script:Files 'shout.txt'
        Set-Content -Path $path -Value 'leise'
        $result = InModuleScope MCPPosh -Parameters @{ Path = $path } { param($Path) ConvertTo-McpMarkdown -Path $Path }
        $result.Content.Trim() | Should -Be 'LEISE'
    }

    It 'refuses to register a duplicate name without -Force' {
        Register-McpDocumentConverter -Name Dup -Extension .dup -ScriptBlock { 'x' } | Out-Null
        { Register-McpDocumentConverter -Name Dup -Extension .dup -ScriptBlock { 'y' } } | Should -Throw '*already registered*'
        { Register-McpDocumentConverter -Name Dup -Extension .dup -ScriptBlock { 'y' } -Force } | Should -Not -Throw
    }

    It 'does not allow removing built-in converters' {
        { Unregister-McpDocumentConverter -Name Markdown -ErrorAction Stop } | Should -Throw
        Get-McpDocumentConverter -Name Markdown | Should -Not -BeNullOrEmpty
    }
}
