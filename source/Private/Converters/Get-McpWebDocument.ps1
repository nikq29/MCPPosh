function Get-McpWebDocument {
    <#
    .SYNOPSIS
        Downloads a URL and converts it to Markdown based on its content type.
    .OUTPUTS
        A hashtable with Content, Title and Format.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri] $Url,

        [string] $Format
    )

    $tempDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('mcpposh-' + [guid]::NewGuid().ToString('N'))
    $null = New-Item -ItemType Directory -Path $tempDirectory -Force
    try {
        $fileName = [System.IO.Path]::GetFileName($Url.AbsolutePath)
        if (-not $fileName) { $fileName = 'index' }
        $tempFile = Join-Path -Path $tempDirectory -ChildPath ([regex]::Replace($fileName, '[^\w.-]', '_'))

        $response = Invoke-WebRequest -Uri $Url -OutFile $tempFile -PassThru -UseBasicParsing -MaximumRedirection 5 -UserAgent 'MCPPosh (PowerShell MCP documentation server)' -ErrorAction Stop
        $contentType = ''
        if ($response -and $response.Headers) {
            $contentType = [string](@($response.Headers['Content-Type']) | Select-Object -First 1)
        }
        $mediaType = ($contentType -split ';')[0].Trim().ToLowerInvariant()

        if (-not $Format) {
            $Format = switch -Regex ($mediaType) {
                '^text/html|^application/xhtml' { 'Html'; break }
                '^text/markdown|^text/x-markdown' { 'Markdown'; break }
                '^application/pdf' { 'Pdf'; break }
                'wordprocessingml' { 'Docx'; break }
                '^text/csv' { 'Csv'; break }
                '^application/json|\+json$' { 'Json'; break }
                '^(application|text)/(x-)?yaml' { 'Yaml'; break }
                '^(application|text)/xml|\+xml$' { 'Xml'; break }
                default { $null }
            }
        }
        if (-not $Format) {
            $byExtension = Get-McpConverter -Path $tempFile
            $Format = if ($byExtension) { $byExtension.Name } else { 'Text' }
        }

        if ($Format -eq 'Html') {
            $html = Read-McpTextFile -Path $tempFile
            $result = ConvertFrom-McpHtml -Html $html -BaseUrl $Url.AbsoluteUri
            $result['Format'] = 'Html'
        }
        else {
            $result = ConvertTo-McpMarkdown -Path $tempFile -Format $Format
        }

        if (-not $result['Title'] -or $result['Title'] -eq [System.IO.Path]::GetFileNameWithoutExtension($tempFile)) {
            $segment = [System.Uri]::UnescapeDataString([System.IO.Path]::GetFileNameWithoutExtension($Url.AbsolutePath))
            $result['Title'] = if ($segment -and $segment -ne 'index') { $segment } else { $Url.Host }
        }
        $result
    }
    finally {
        Remove-Item -LiteralPath $tempDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}
