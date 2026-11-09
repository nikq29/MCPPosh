$script:McpCodeLanguages = @{
    '.ps1' = 'powershell'; '.psm1' = 'powershell'; '.psd1' = 'powershell'; '.ps1xml' = 'xml'
    '.py' = 'python'; '.js' = 'javascript'; '.mjs' = 'javascript'; '.cjs' = 'javascript'; '.jsx' = 'jsx'
    '.ts' = 'typescript'; '.tsx' = 'tsx'; '.cs' = 'csharp'; '.csx' = 'csharp'; '.fs' = 'fsharp'; '.vb' = 'vbnet'
    '.java' = 'java'; '.kt' = 'kotlin'; '.kts' = 'kotlin'; '.scala' = 'scala'; '.groovy' = 'groovy'; '.go' = 'go'
    '.rs' = 'rust'; '.c' = 'c'; '.h' = 'c'; '.cpp' = 'cpp'; '.cc' = 'cpp'; '.hpp' = 'cpp'; '.swift' = 'swift'
    '.rb' = 'ruby'; '.php' = 'php'; '.pl' = 'perl'; '.lua' = 'lua'; '.r' = 'r'; '.dart' = 'dart'
    '.sh' = 'bash'; '.bash' = 'bash'; '.zsh' = 'bash'; '.bat' = 'batch'; '.cmd' = 'batch'
    '.sql' = 'sql'; '.kql' = 'kusto'; '.graphql' = 'graphql'; '.proto' = 'protobuf'
    '.css' = 'css'; '.scss' = 'scss'; '.less' = 'less'; '.vue' = 'vue'; '.svelte' = 'svelte'
    '.tf' = 'hcl'; '.hcl' = 'hcl'; '.bicep' = 'bicep'; '.ini' = 'ini'; '.toml' = 'toml'; '.conf' = 'ini'
    '.cfg' = 'ini'; '.properties' = 'properties'; '.env' = 'bash'; '.gradle' = 'groovy'
    '.dockerfile' = 'dockerfile'; '.makefile' = 'makefile'
}

$script:McpCodeFileNames = @{
    'dockerfile' = 'dockerfile'; 'makefile' = 'makefile'; 'jenkinsfile' = 'groovy'; 'vagrantfile' = 'ruby'
    'gemfile' = 'ruby'; 'rakefile' = 'ruby'; 'procfile' = 'bash'
}

function Initialize-McpConverterRegistry {
    [CmdletBinding()]
    param()

    $script:McpConverters = [System.Collections.Generic.List[object]]::new()
    $builtins = @(
        @{ Name = 'Markdown'; Extensions = '.md', '.markdown', '.mdx', '.mkd'; ScriptBlock = { param($Path) ConvertFrom-McpMarkdownFile -Path $Path } }
        @{ Name = 'Text'; Extensions = '.txt', '.text', '.log', '.rst', '.adoc', '.asciidoc', '.org', '.textile'; ScriptBlock = { param($Path) ConvertFrom-McpTextFile -Path $Path } }
        @{ Name = 'Html'; Extensions = '.html', '.htm', '.xhtml'; ScriptBlock = { param($Path) ConvertFrom-McpHtmlFile -Path $Path } }
        @{ Name = 'Docx'; Extensions = , '.docx'; ScriptBlock = { param($Path) ConvertFrom-McpDocxFile -Path $Path } }
        @{ Name = 'Pdf'; Extensions = , '.pdf'; ScriptBlock = { param($Path) ConvertFrom-McpPdfFile -Path $Path } }
        @{ Name = 'Csv'; Extensions = '.csv', '.tsv'; ScriptBlock = { param($Path) ConvertFrom-McpCsvFile -Path $Path } }
        @{ Name = 'Json'; Extensions = '.json', '.jsonc', '.json5', '.jsonl'; ScriptBlock = { param($Path) ConvertFrom-McpCodeFile -Path $Path -Language 'json' -Format 'Json' } }
        @{ Name = 'Yaml'; Extensions = '.yaml', '.yml'; ScriptBlock = { param($Path) ConvertFrom-McpCodeFile -Path $Path -Language 'yaml' -Format 'Yaml' } }
        @{ Name = 'Xml'; Extensions = '.xml', '.xsd', '.xsl', '.xslt', '.config', '.csproj', '.props', '.targets', '.resx', '.svg'; ScriptBlock = { param($Path) ConvertFrom-McpCodeFile -Path $Path -Language 'xml' -Format 'Xml' } }
        @{ Name = 'Code'; Extensions = [string[]]$script:McpCodeLanguages.Keys; ScriptBlock = { param($Path) ConvertFrom-McpCodeFile -Path $Path } }
    )
    foreach ($builtin in $builtins) {
        $script:McpConverters.Add([pscustomobject]@{
                PSTypeName  = 'MCPPosh.Converter'
                Name        = $builtin.Name
                Extensions  = [string[]]@($builtin.Extensions | Sort-Object)
                ScriptBlock = $builtin.ScriptBlock
                Builtin     = $true
            })
    }
}

function Get-McpConverter {
    <#
    .SYNOPSIS
        Finds the converter for a file (by extension or well-known file name) or by format name.
        Custom converters take precedence over built-in ones.
    #>
    [CmdletBinding()]
    param(
        [string] $Path,

        [string] $Format
    )

    $converters = $script:McpConverters.ToArray()
    [array]::Reverse($converters)

    if ($Format) {
        $match = $converters | Where-Object { $_.Name -eq $Format } | Select-Object -First 1
        if (-not $match) {
            $names = ($script:McpConverters | ForEach-Object Name | Sort-Object -Unique) -join ', '
            throw "Unknown format '$Format'. Available formats: $names"
        }
        return $match
    }

    $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
    if ($extension) {
        $match = $converters | Where-Object { $_.Extensions -contains $extension } | Select-Object -First 1
        if ($match) { return $match }
    }

    $fileName = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
    if ($script:McpCodeFileNames.ContainsKey($fileName)) {
        return $converters | Where-Object { $_.Name -eq 'Code' } | Select-Object -First 1
    }

    if (Test-McpTextFile -Path $Path) {
        return $converters | Where-Object { $_.Name -eq 'Text' } | Select-Object -First 1
    }
    $null
}

function Test-McpTextFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $buffer = [byte[]]::new(8192)
        $read = $stream.Read($buffer, 0, $buffer.Length)
        for ($i = 0; $i -lt $read; $i++) {
            if ($buffer[$i] -eq 0) { return $false }
        }
        return $true
    }
    finally {
        $stream.Dispose()
    }
}

function ConvertTo-McpMarkdown {
    <#
    .SYNOPSIS
        Converts a file to Markdown using the matching converter.
    .OUTPUTS
        A hashtable with Content, Title, Format and Tags.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [string] $Format
    )

    $converter = Get-McpConverter -Path $Path -Format $Format
    if (-not $converter) {
        throw "No converter found for '$Path'. Register one with Register-McpDocumentConverter or pass -Format."
    }

    $raw = & $converter.ScriptBlock $Path
    $result = @{
        Content = $null
        Title   = $null
        Format  = $converter.Name
        Tags    = @()
    }
    if ($raw -is [string]) {
        $result.Content = $raw
    }
    elseif ($raw -is [System.Collections.IDictionary]) {
        $result.Content = [string]$raw['Content']
        if ($raw['Title']) { $result.Title = [string]$raw['Title'] }
        if ($raw['Tags']) { $result.Tags = @($raw['Tags']) }
        if ($raw['Format']) { $result.Format = [string]$raw['Format'] }
    }
    elseif ($null -ne $raw -and $raw.PSObject.Properties['Content']) {
        $result.Content = [string]$raw.Content
        if ($raw.PSObject.Properties['Title'] -and $raw.Title) { $result.Title = [string]$raw.Title }
        if ($raw.PSObject.Properties['Tags'] -and $raw.Tags) { $result.Tags = @($raw.Tags) }
    }
    elseif ($null -ne $raw) {
        $result.Content = (@($raw) | ForEach-Object { [string]$_ }) -join "`n"
    }

    if ($null -eq $result.Content) {
        throw "Converter '$($converter.Name)' returned no content for '$Path'."
    }
    if (-not $result.Title) {
        $result.Title = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    }
    $result
}
