# Module-level state. ModuleBuilder places this file at the top of the built MCPPosh.psm1.

$script:ModuleRoot = $PSScriptRoot
$script:ModuleManifestPath = Join-Path -Path $PSScriptRoot -ChildPath 'MCPPosh.psd1'
$script:ModuleVersion = '0.0.0'
if (Test-Path -LiteralPath $script:ModuleManifestPath) {
    $mcpManifestData = Import-PowerShellDataFile -Path $script:ModuleManifestPath
    $script:ModuleVersion = [string]$mcpManifestData.ModuleVersion
    $mcpPrerelease = $mcpManifestData.PrivateData.PSData.Prerelease
    if (-not [string]::IsNullOrWhiteSpace($mcpPrerelease)) {
        $script:ModuleVersion = '{0}-{1}' -f $script:ModuleVersion, $mcpPrerelease
    }
    Remove-Variable -Name mcpManifestData, mcpPrerelease -ErrorAction SilentlyContinue
}

Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.ZipFile

$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# MCP protocol revisions this server can speak, newest first.
$script:McpSupportedProtocolVersions = @('2025-11-25', '2025-06-18', '2025-03-26', '2024-11-05')

# Resource limits against oversized input and decompression bombs.
$script:McpMaxRequestBytes = 10MB       # HTTP request body, counted while reading (also for chunked requests)
$script:McpMaxBatchSize = 100           # JSON-RPC messages per batch
$script:McpMaxArchiveBytes = 1GB        # uncompressed size of all files in an imported knowledge base archive
$script:McpMaxArchiveEntries = 100000   # files in an imported knowledge base archive
$script:McpMaxZipEntryBytes = 64MB      # uncompressed size of one part read from a .docx file

# Search index cache, keyed by knowledge base path.
$script:McpIndexCache = @{}

# Registered document converters (filled by Initialize-McpConverterRegistry in suffix.ps1).
$script:McpConverters = [System.Collections.Generic.List[object]]::new()

# Fenced code block languages by file extension and by well-known file name.
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

# Search: stop words (English and German, diacritics already folded) and light suffix stripping.
# Suffixes are applied repeatedly so that e.g. "servers" -> "server" -> "serv" and "server" -> "serv" match.
$script:McpStopWords = [System.Collections.Generic.HashSet[string]]::new(
    [string[]]@(
        # English
        'a', 'an', 'and', 'are', 'as', 'at', 'be', 'been', 'but', 'by', 'can', 'could', 'did', 'do', 'does', 'for', 'from',
        'had', 'has', 'have', 'he', 'her', 'his', 'how', 'if', 'in', 'into', 'is', 'it', 'its', 'me', 'my', 'no', 'not', 'of',
        'on', 'or', 'our', 'she', 'so', 'such', 'than', 'that', 'the', 'their', 'them', 'then', 'there', 'these', 'they',
        'this', 'those', 'to', 'too', 'us', 'was', 'we', 'were', 'what', 'when', 'where', 'which', 'who', 'why', 'will',
        'with', 'would', 'you', 'your',
        # German
        'aber', 'als', 'am', 'an', 'auch', 'auf', 'aus', 'bei', 'bin', 'bis', 'bist', 'da', 'damit', 'dann', 'das', 'dass',
        'dein', 'deine', 'dem', 'den', 'der', 'des', 'dessen', 'die', 'dies', 'diese', 'diesem', 'diesen', 'dieser', 'dieses',
        'du', 'durch', 'ein', 'eine', 'einem', 'einen', 'einer', 'eines', 'er', 'es', 'euer', 'eure', 'fur', 'hab', 'habe',
        'haben', 'hat', 'hatte', 'ich', 'ihr', 'ihre', 'im', 'in', 'ist', 'ja', 'jede', 'jeder', 'kann', 'kein', 'keine',
        'man', 'mein', 'meine', 'mit', 'muss', 'nach', 'nicht', 'noch', 'nur', 'ob', 'oder', 'ohne', 'sein', 'seine', 'sich',
        'sie', 'sind', 'so', 'soll', 'uber', 'um', 'und', 'uns', 'unser', 'unter', 'vom', 'von', 'vor', 'war', 'waren', 'was',
        'weil', 'wenn', 'wer', 'werden', 'wie', 'wir', 'wird', 'wo', 'zu', 'zum', 'zur'
    ),
    [System.StringComparer]::Ordinal)
$script:McpSuffixes = [string[]]@('ungen', 'heiten', 'keiten', 'ingen', 'ung', 'heit', 'keit', 'ing', 'ies', 'ern', 'en', 'er', 'es', 'ed', 'e', 's')
