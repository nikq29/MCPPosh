function ConvertFrom-McpCodeFile {
    <#
    .SYNOPSIS
        Converts a source code or data file to Markdown.

    .DESCRIPTION
        Wraps the content of a source code or structured data file (JSON, YAML, XML, PowerShell, Python and more) in a fenced Markdown code block with the language derived from the extension or file name, preceded by the file name as heading.

    .PARAMETER Path
        Path of the source code or data file to convert.

    .PARAMETER Language
        Language of the code fence, for example json or powershell. Detected from the file when omitted.

    .PARAMETER Format
        Format name stored with the document, for example Code, Json, Yaml or Xml.

    .EXAMPLE
        ConvertFrom-McpCodeFile -Path ./scripts/deploy.ps1

        Returns a hashtable whose Content is a powershell code block titled deploy.ps1.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [string] $Language,

        [string] $Format = 'Code'
    )

    if (-not $Language) {
        $extension = [System.IO.Path]::GetExtension($Path).ToLowerInvariant()
        $fileName = [System.IO.Path]::GetFileName($Path).ToLowerInvariant()
        $Language = if ($script:McpCodeLanguages.ContainsKey($extension)) { $script:McpCodeLanguages[$extension] }
        elseif ($script:McpCodeFileNames.ContainsKey($fileName)) { $script:McpCodeFileNames[$fileName] }
        else { '' }
    }

    $code = (Read-McpTextFile -Path $Path).TrimEnd()
    $fence = Get-McpCodeFence -Text $code
    $fileName = [System.IO.Path]::GetFileName($Path)
    @{
        Content = "# $fileName`n`n$fence$Language`n$code`n$fence`n"
        Title   = $fileName
        Format  = $Format
    }
}
