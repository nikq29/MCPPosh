<#
    Shared helpers for the MCPPosh Pester tests.

    The tests run against the module built by Sampler (./build.ps1 -Tasks build). When the tests
    are started through ./build.ps1 -Tasks test, Sampler puts output/module first on PSModulePath;
    when they are started with Invoke-Pester directly, the built module is located in output/module.
#>

$script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

function Get-McpTestModuleManifest {
    $available = Get-Module -Name MCPPosh -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
    if ($available) { return $available.Path }
    $built = Get-ChildItem -Path (Join-Path $script:RepoRoot 'output/module/MCPPosh') -Filter 'MCPPosh.psd1' -Recurse -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $built) { throw 'MCPPosh is not built. Run ./build.ps1 -ResolveDependency -Tasks build first.' }
    $built.FullName
}

function Initialize-McpTestEnvironment {
    <# Creates an isolated MCPPOSH_HOME, imports the built module globally and returns the home path. #>
    param([string] $Name = 'test')

    $homePath = Join-Path ([System.IO.Path]::GetTempPath()) ('mcpposh-test-' + [guid]::NewGuid().ToString('N').Substring(0, 12) + "-$Name")
    New-Item -ItemType Directory -Path $homePath -Force | Out-Null
    $env:MCPPOSH_HOME = $homePath
    Import-Module -Name (Get-McpTestModuleManifest) -Force -Global -ErrorAction Stop
    $homePath
}

function Remove-McpTestEnvironment {
    param([string] $Path)

    if ($Path -and (Test-Path -LiteralPath $Path)) {
        Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Item -Path Env:MCPPOSH_HOME -ErrorAction SilentlyContinue
}

function New-McpTestContext {
    <# Returns a server context for a knowledge base, created inside the module scope. #>
    param(
        [string] $KnowledgeBase = 'Default',
        [switch] $AllowWrite,
        [ValidateSet('Stdio', 'Http')] [string] $Transport = 'Stdio'
    )

    & (Get-Module -Name MCPPosh) {
        param($KnowledgeBase, $AllowWrite, $Transport)
        $kb = Resolve-McpKnowledgeBase -KnowledgeBase $KnowledgeBase -CreateIfMissing
        New-McpServerContext -KnowledgeBase $kb -Transport $Transport -AllowWrite:$AllowWrite -LogPath (Join-Path $kb.Path 'logs/test.log')
    } $KnowledgeBase $AllowWrite.IsPresent $Transport
}

function Invoke-McpTestMessage {
    <# Sends a JSON-RPC message (hashtable or JSON string) through Invoke-McpMessage and returns the parsed response. #>
    param(
        [Parameter(Mandatory)] [object] $Message,
        [string] $KnowledgeBase = 'Default',
        [switch] $AllowWrite
    )

    $json = if ($Message -is [string]) { $Message } else { $Message | ConvertTo-Json -Depth 20 -Compress }
    $context = New-McpTestContext -KnowledgeBase $KnowledgeBase -AllowWrite:$AllowWrite
    $response = & (Get-Module -Name MCPPosh) { param($Context, $Json) Invoke-McpMessage -Context $Context -Json $Json } $context $json
    if ($null -ne $response) { $response | ConvertFrom-Json -Depth 50 }
}

function New-McpTestDocx {
    <# Creates a minimal but valid .docx with a title, localized headings, a list and a table. #>
    param([Parameter(Mandatory)] [string] $Path)

    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.ZipFile
    $w = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    $document = @"
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="$w">
  <w:body>
    <w:p><w:pPr><w:pStyle w:val="berschrift1"/></w:pPr><w:r><w:t>Operations Handbook</w:t></w:r></w:p>
    <w:p><w:r><w:t xml:space="preserve">This handbook describes the </w:t></w:r><w:r><w:rPr><w:b/></w:rPr><w:t>emergency mode</w:t></w:r><w:r><w:t>.</w:t></w:r></w:p>
    <w:p><w:pPr><w:pStyle w:val="berschrift2"/></w:pPr><w:r><w:t>Escalation</w:t></w:r></w:p>
    <w:p><w:pPr><w:numPr><w:ilvl w:val="0"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Call the control center</w:t></w:r></w:p>
    <w:p><w:pPr><w:numPr><w:ilvl w:val="1"/><w:numId w:val="1"/></w:numPr></w:pPr><w:r><w:t>Create a ticket</w:t></w:r></w:p>
    <w:tbl>
      <w:tr><w:tc><w:p><w:r><w:t>Level</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Contact</w:t></w:r></w:p></w:tc></w:tr>
      <w:tr><w:tc><w:p><w:r><w:t>1</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Service desk | 24/7</w:t></w:r></w:p></w:tc></w:tr>
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
  <dc:title>Emergency Handbook</dc:title>
</cp:coreProperties>
"@
    $contentTypes = '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>'

    if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Force }
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

$script:AzStubs = @{
    'New-AzStorageContext'     = { param($StorageAccountName, $StorageAccountKey, $SasToken) }
    'Get-AzStorageAccountKey'  = { param($ResourceGroupName, $Name) }
    'Get-AzStorageFile'        = { param($ShareName, $Path, $Context, [Parameter(ValueFromPipeline)] $Directory) process { } }
    'New-AzStorageDirectory'   = { param($ShareName, $Path, $Context) }
    'Set-AzStorageFileContent' = { param($ShareName, $Source, $Path, $Context, [switch] $Force) }
    'Remove-AzStorageFile'     = { param($ShareName, $Path, $Context) }
}

function Register-McpTestAzStub {
    <#
        Defines global stub functions for the Az.Storage cmdlets. Functions take precedence over cmdlets, so the
        stubs shadow an installed Az.Storage module and Pester mocks them with untyped parameters. Without this the
        mocks would inherit the typed parameters of the real cmdlets (for example -Context [IStorageContext]).
    #>
    foreach ($stub in $script:AzStubs.GetEnumerator()) {
        Set-Item -Path "function:global:$($stub.Key)" -Value $stub.Value
    }
}

function Unregister-McpTestAzStub {
    foreach ($name in $script:AzStubs.Keys) {
        Remove-Item -Path "function:global:$name" -ErrorAction SilentlyContinue
    }
}

Export-ModuleMember -Function *
