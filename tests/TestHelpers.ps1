# Shared helpers for the Pester tests. Dot-source in BeforeAll.

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
# Tests run against the module built by Sampler (./build.ps1 -Tasks build), which the build puts on PSModulePath.
$script:ModuleManifest = (Get-Module -Name MCPPosh -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Path
if (-not $script:ModuleManifest) {
    $script:ModuleManifest = Get-ChildItem -Path (Join-Path $script:RepoRoot 'output/module/MCPPosh') -Filter MCPPosh.psd1 -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty FullName
}

function Initialize-McpTestEnvironment {
    param([string] $Name = 'home')

    $homePath = Join-Path ([System.IO.Path]::GetTempPath()) ('mcpposh-test-' + [guid]::NewGuid().ToString('N') + "-$Name")
    New-Item -ItemType Directory -Path $homePath -Force | Out-Null
    $env:MCPPOSH_HOME = $homePath
    Import-Module $script:ModuleManifest -Force
    $homePath
}

function Remove-McpTestEnvironment {
    param([string] $Path)

    if ($Path -and (Test-Path $Path)) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item Env:MCPPOSH_HOME -ErrorAction SilentlyContinue
}

function New-McpTestDocx {
    <# Creates a minimal but valid .docx with a title, headings, a list and a table. #>
    param([Parameter(Mandatory)][string] $Path)

    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.ZipFile
    $w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    $document = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="$w">
  <w:body>
    <w:p><w:pPr><w:pStyle w:val="berschrift1"/></w:pPr><w:r><w:t>Betriebshandbuch</w:t></w:r></w:p>
    <w:p><w:r><w:t xml:space="preserve">Dieses Handbuch beschreibt den </w:t></w:r><w:r><w:rPr><w:b/></w:rPr><w:t>Notfallbetrieb</w:t></w:r><w:r><w:t>.</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="berschrift2"/></w:pPr><w:r><w:t>Eskalation</w:t></w:r></w:p>
    <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Leitstelle anrufen</w:t></w:r></w:p>
    <w:p><w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Ticket erstellen</w:t></w:r></w:p>
    <w:tbl>
      <w:tr><w:tc><w:p><w:r><w:t>Stufe</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Kontakt</w:t></w:r></w:p></w:tc></w:tr>
      <w:tr><w:tc><w:p><w:r><w:t>1</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Servicedesk | 24/7</w:t></w:r></w:p></w:tc></w:tr>
    </w:tbl>
  </w:body>
</w:document>
"@
    $styles = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="$w">
  <w:style w:type="paragraph" w:styleId="berschrift1"><w:name w:val="heading 1"/></w:style>
  <w:style w:type="paragraph" w:styleId="berschrift2"><w:name w:val="heading 2"/></w:style>
</w:styles>
"@
    $core = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <dc:title>Handbuch Notfallbetrieb</dc:title>
</cp:coreProperties>
"@
    $contentTypes = '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'

    if (Test-Path $Path) { Remove-Item $Path -Force }
    $archive = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        foreach ($entry in @(
                @('[Content_Types].xml', $contentTypes),
                @('word/document.xml', $document),
                @('word/styles.xml', $styles),
                @('docProps/core.xml', $core))) {
            $zipEntry = $archive.CreateEntry($entry[0])
            $writer = [System.IO.StreamWriter]::new($zipEntry.Open(), [System.Text.UTF8Encoding]::new($false))
            try { $writer.Write($entry[1]) } finally { $writer.Dispose() }
        }
    }
    finally {
        $archive.Dispose()
    }
}
