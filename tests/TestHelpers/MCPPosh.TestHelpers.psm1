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
    Remove-Variable -Name McpTestAzFileShareRoot, McpTestAzFileShareLog -Scope Global -ErrorAction SilentlyContinue
}

#region Integration test helpers

function Get-McpTestFreePort {
    <# Returns a free TCP port on the loopback interface. #>
    & (Get-Module -Name MCPPosh) { Get-McpFreePort }
}

function ConvertTo-McpTestEncodedCommand {
    <#
        Turns a script block and its arguments into a value for pwsh -EncodedCommand. Integration tests write the
        commands of child processes as script block literals so the QA guard (tests/QA/integration.tests.ps1)
        sees the MCPPosh calls in them.
    #>
    param(
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
        [object[]] $ArgumentList = @()
    )

    $arguments = @($ArgumentList | ForEach-Object { "'" + ([string]$_).Replace("'", "''") + "'" }) -join ' '
    $command = "`$ErrorActionPreference = 'Stop'; `$ProgressPreference = 'SilentlyContinue'; & {$ScriptBlock} $arguments"
    [System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
}

function Start-McpTestProcess {
    <# Starts pwsh with a script block in a new process; stdout and stderr go to files. Returns the process. #>
    param(
        [Parameter(Mandatory)] [scriptblock] $ScriptBlock,
        [object[]] $ArgumentList = @(),
        [Parameter(Mandatory)] [string] $OutputPath
    )

    $pwsh = & (Get-Module -Name MCPPosh) { Get-McpPwshPath }
    $encoded = ConvertTo-McpTestEncodedCommand -ScriptBlock $ScriptBlock -ArgumentList $ArgumentList
    Start-Process -FilePath $pwsh -ArgumentList '-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded `
        -RedirectStandardOutput $OutputPath -RedirectStandardError "$OutputPath.err" -PassThru
}

function Wait-McpTestCondition {
    <# Polls a script block until it returns a truthy value or the timeout expires. #>
    param(
        [Parameter(Mandatory)] [scriptblock] $Condition,
        [int] $TimeoutSeconds = 60,
        [string] $Because = 'the condition was not met'
    )

    $deadline = [datetime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $result = try { & $Condition } catch { $null }
        if ($result) { return $result }
        Start-Sleep -Milliseconds 250
    } while ([datetime]::UtcNow -lt $deadline)
    throw "Timed out after $TimeoutSeconds seconds: $Because."
}

function Invoke-McpTestStdioSession {
    <#
        Starts an MCP stdio server process, writes JSON-RPC messages (one per line), closes stdin and returns the
        parsed responses together with stdout lines, stderr and the exit code.
    #>
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [string[]] $ArgumentList = @(),
        [System.Collections.IDictionary] $Environment,
        [Parameter(Mandatory)] [string[]] $Message,
        [int] $TimeoutSeconds = 120
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new($FilePath)
    foreach ($argument in $ArgumentList) { $startInfo.ArgumentList.Add($argument) }
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardInput = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    if ($Environment) {
        foreach ($key in $Environment.Keys) { $startInfo.Environment[[string]$key] = [string]$Environment[$key] }
    }

    $process = [System.Diagnostics.Process]::Start($startInfo)
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        foreach ($line in $Message) { $process.StandardInput.WriteLine($line) }
        $process.StandardInput.Close()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill($true)
            throw "The stdio server did not exit within $TimeoutSeconds seconds."
        }
        $lines = @($stdout.Result -split "`r?`n" | Where-Object { $_ })
        [pscustomobject]@{
            Lines     = $lines
            Responses = @($lines | ForEach-Object { $_ | ConvertFrom-Json -Depth 50 })
            StdErr    = $stderr.Result
            ExitCode  = $process.ExitCode
        }
    }
    finally {
        $process.Dispose()
    }
}

function Get-McpTestRpcMessage {
    <# Returns JSON-RPC messages for an MCP session: initialize, initialized and the given tool calls. #>
    param(
        [object[]] $ToolCall = @(),
        [switch] $ListTools
    )

    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"integration","version":"1"}}}'
    '{"jsonrpc":"2.0","method":"notifications/initialized"}'
    $id = 1
    if ($ListTools) {
        $id++
        '{"jsonrpc":"2.0","id":' + $id + ',"method":"tools/list"}'
    }
    foreach ($call in $ToolCall) {
        $id++
        @{ jsonrpc = '2.0'; id = $id; method = 'tools/call'; params = @{ name = $call.Name; arguments = $call.Arguments } } |
            ConvertTo-Json -Depth 10 -Compress
    }
}

function Get-McpTestClientEntry {
    <# Returns the name and the server entry of a client configuration (mcpServers or servers format). #>
    param([Parameter(Mandatory)] [string] $Json)

    $config = $Json | ConvertFrom-Json -AsHashtable
    $servers = if ($config.ContainsKey('mcpServers')) { $config['mcpServers'] } else { $config['servers'] }
    $name = @($servers.Keys)[0]
    [pscustomobject]@{ Name = $name; Entry = $servers[$name]; Config = $config }
}

function New-McpTestPdf {
    <# Creates a minimal valid PDF 1.4 with one page of text (Helvetica) and a correct cross-reference table. #>
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Text
    )

    $stream = "BT /F1 12 Tf 72 720 Td ($Text) Tj ET"
    $objects = @(
        '<< /Type /Catalog /Pages 2 0 R >>'
        '<< /Type /Pages /Kids [3 0 R] /Count 1 >>'
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>'
        "<< /Length $($stream.Length) >>`nstream`n$stream`nendstream"
        '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>'
    )
    $builder = [System.Text.StringBuilder]::new("%PDF-1.4`n")
    $offsets = for ($i = 0; $i -lt $objects.Count; $i++) {
        $builder.Length
        $null = $builder.Append("$($i + 1) 0 obj`n$($objects[$i])`nendobj`n")
    }
    $xref = $builder.Length
    $null = $builder.Append("xref`n0 $($objects.Count + 1)`n0000000000 65535 f `n")
    foreach ($offset in $offsets) { $null = $builder.Append(('{0:D10} 00000 n ' -f $offset) + "`n") }
    $null = $builder.Append("trailer`n<< /Size $($objects.Count + 1) /Root 1 0 R >>`nstartxref`n$xref`n%%EOF`n")
    [System.IO.File]::WriteAllText($Path, $builder.ToString(), [System.Text.Encoding]::ASCII)
}

function Test-McpTestPdfSupport {
    <# Returns $true when PSWritePDF or pdftotext is available for PDF text extraction. #>
    [bool](Get-Module -ListAvailable -Name PSWritePDF) -or
    [bool](Get-Command -Name pdftotext -CommandType Application -ErrorAction SilentlyContinue)
}

$script:McpTestFixtures = [ordered]@{
    Markdown = @{ File = 'aardvark.md'; Keyword = 'aardvark'; Content = "# Aardvark`n`nThe aardvark digs burrows at night." }
    Text     = @{ File = 'bluebell.txt'; Keyword = 'bluebell'; Content = "Bluebell notes`n`nThe bluebell flowers in spring." }
    Html     = @{ File = 'cormorant.html'; Keyword = 'cormorant'; Content = '<html><head><title>Cormorant</title></head><body><h1>Birds</h1><p>The cormorant dives for fish.</p></body></html>' }
    Docx     = @{ File = 'handbook.docx'; Keyword = 'escalation' }
    Pdf      = @{ File = 'dolphin.pdf'; Keyword = 'dolphin'; Content = 'The dolphin sleeps with one eye open.' }
    Csv      = @{ File = 'falcon.csv'; Keyword = 'falcon'; Content = "Name,Speed`nfalcon,389" }
    Json     = @{ File = 'gazelle.json'; Keyword = 'gazelle'; Content = '{ "service": { "name": "gazelle", "port": 8080 } }' }
    Yaml     = @{ File = 'hedgehog.yaml'; Keyword = 'hedgehog'; Content = "service:`n  name: hedgehog`n  port: 8081" }
    Xml      = @{ File = 'ibex.xml'; Keyword = 'ibex'; Content = '<config><service><name>ibex</name><port>8082</port></service></config>' }
    Code     = @{ File = 'jackal.ps1'; Keyword = 'jackal'; Content = "function Get-Jackal {`n    # Returns the jackal configuration.`n    'jackal'`n}" }
}

function Get-McpTestFixtureFormat {
    <# Returns the converter names that New-McpTestFixture can create files for. #>
    $script:McpTestFixtures.Keys
}

function New-McpTestFixture {
    <# Creates a file for a built-in converter that contains a unique keyword. Returns Path, Keyword and Format. #>
    param(
        [Parameter(Mandatory)] [string] $Format,
        [Parameter(Mandatory)] [string] $Directory
    )

    if (-not $script:McpTestFixtures.Contains($Format)) {
        throw "There is no integration test fixture for the converter '$Format'. Add one to `$script:McpTestFixtures."
    }
    $fixture = $script:McpTestFixtures[$Format]
    $null = New-Item -ItemType Directory -Path $Directory -Force
    $path = Join-Path -Path $Directory -ChildPath $fixture.File
    switch ($Format) {
        'Docx' { New-McpTestDocx -Path $path }
        'Pdf' { New-McpTestPdf -Path $path -Text $fixture.Content }
        default { [System.IO.File]::WriteAllText($path, $fixture.Content, [System.Text.UTF8Encoding]::new($false)) }
    }
    [pscustomobject]@{ Format = $Format; Path = $path; Keyword = $fixture.Keyword }
}

function Start-McpTestWebServer {
    <#
        Serves the files of a folder over HTTP on localhost (HttpListener in a thread job). The content type
        follows the file extension. Files can be changed between requests. Returns Uri, Listener and Job.
    #>
    param([Parameter(Mandatory)] [string] $Root)

    $null = New-Item -ItemType Directory -Path $Root -Force
    $port = Get-McpTestFreePort
    $listener = [System.Net.HttpListener]::new()
    $listener.Prefixes.Add("http://localhost:$port/")
    $listener.Start()
    $job = Start-ThreadJob -ArgumentList $listener, $Root -ScriptBlock {
        param($Listener, $Root)
        $types = @{
            '.html' = 'text/html; charset=utf-8'
            '.md'   = 'text/markdown; charset=utf-8'
            '.csv'  = 'text/csv; charset=utf-8'
            '.json' = 'application/json'
            '.txt'  = 'text/plain; charset=utf-8'
        }
        while ($Listener.IsListening) {
            try { $context = $Listener.GetContext() } catch { break }
            try {
                $relative = [System.Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart('/'))
                $file = Join-Path -Path $Root -ChildPath $relative
                if ($relative -and (Test-Path -LiteralPath $file -PathType Leaf)) {
                    $bytes = [System.IO.File]::ReadAllBytes($file)
                    $type = $types[[System.IO.Path]::GetExtension($file).ToLowerInvariant()]
                    $context.Response.ContentType = if ($type) { $type } else { 'application/octet-stream' }
                    $context.Response.ContentLength64 = $bytes.Length
                    $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
                }
                else {
                    $context.Response.StatusCode = 404
                }
            }
            finally {
                $context.Response.Close()
            }
        }
    }
    [pscustomobject]@{ Uri = "http://localhost:$port/"; Listener = $listener; Job = $job; Root = $Root }
}

function Stop-McpTestWebServer {
    param([Parameter(Mandatory)] [object] $Server)

    $Server.Listener.Stop()
    $Server.Listener.Close()
    $Server.Job | Stop-Job -PassThru | Remove-Job -Force
}

function Register-McpTestAzFileShare {
    <#
        Replaces the Az.Storage cmdlets used by Publish-McpKnowledgeBase with global functions that store the
        files in a local folder: <Root>/<storage account>/<share>/<path>. Like Azure Files, the share must exist
        (create the folder first) and parent directories must exist before files are uploaded. Every change is
        recorded in $global:McpTestAzFileShareLog.
    #>
    param([Parameter(Mandatory)] [string] $Root)

    $global:McpTestAzFileShareRoot = $Root
    $global:McpTestAzFileShareLog = [System.Collections.Generic.List[object]]::new()
    $stubs = @{
        'New-AzStorageContext'     = {
            [CmdletBinding()]
            param($StorageAccountName, $StorageAccountKey, $SasToken)
            [pscustomobject]@{
                StorageAccountName = $StorageAccountName
                Credential         = if ($SasToken) { 'Sas' } else { 'Key' }
                LocalRoot          = Join-Path -Path $global:McpTestAzFileShareRoot -ChildPath $StorageAccountName
            }
        }
        'Get-AzStorageAccountKey'  = {
            [CmdletBinding()]
            param($ResourceGroupName, $Name)
            $global:McpTestAzFileShareLog.Add([pscustomobject]@{ Action = 'GetKey'; Path = "$ResourceGroupName/$Name" })
            @([pscustomobject]@{ KeyName = 'key1'; Value = "key-of-$Name" })
        }
        'Get-AzStorageFile'        = {
            [CmdletBinding()]
            param($ShareName, $Path, $Context, [Parameter(ValueFromPipeline)] $Directory)
            process {
                if ($Directory) {
                    foreach ($item in (Get-ChildItem -LiteralPath $Directory.LocalPath)) {
                        [pscustomobject]@{ Name = $item.Name; LocalPath = $item.FullName }
                    }
                    return
                }
                $local = Join-Path -Path $Context.LocalRoot -ChildPath "$ShareName/$Path"
                if (Test-Path -LiteralPath $local) {
                    [pscustomobject]@{ Name = Split-Path -Path $local -Leaf; LocalPath = $local }
                }
                else {
                    Write-Error -Message "The specified resource does not exist: $ShareName/$Path"
                }
            }
        }
        'New-AzStorageDirectory'   = {
            [CmdletBinding()]
            param($ShareName, $Path, $Context)
            $local = Join-Path -Path $Context.LocalRoot -ChildPath "$ShareName/$Path"
            if (-not (Test-Path -LiteralPath (Split-Path -Path $local -Parent))) { throw "The parent of '$Path' does not exist." }
            $null = New-Item -ItemType Directory -Path $local
            $global:McpTestAzFileShareLog.Add([pscustomobject]@{ Action = 'CreateDirectory'; Path = $Path })
        }
        'Set-AzStorageFileContent' = {
            [CmdletBinding()]
            param($ShareName, $Source, $Path, $Context, [switch] $Force)
            $local = Join-Path -Path $Context.LocalRoot -ChildPath "$ShareName/$Path"
            if (-not (Test-Path -LiteralPath (Split-Path -Path $local -Parent))) { throw "The parent directory of '$Path' does not exist." }
            Copy-Item -LiteralPath $Source -Destination $local -Force
            $global:McpTestAzFileShareLog.Add([pscustomobject]@{ Action = 'Upload'; Path = $Path })
        }
        'Remove-AzStorageFile'     = {
            [CmdletBinding()]
            param($ShareName, $Path, $Context)
            Remove-Item -LiteralPath (Join-Path -Path $Context.LocalRoot -ChildPath "$ShareName/$Path") -Force
            $global:McpTestAzFileShareLog.Add([pscustomobject]@{ Action = 'Delete'; Path = $Path })
        }
    }
    foreach ($stub in $stubs.GetEnumerator()) {
        Set-Item -Path "function:global:$($stub.Key)" -Value $stub.Value
    }
}

#endregion

Export-ModuleMember -Function *
