function ConvertTo-McpMarkdown {
    <#
    .SYNOPSIS
        Converts a file to Markdown using the matching converter.

    .DESCRIPTION
        Selects the converter for a file (or the converter named with -Format), runs it and normalizes its result to a hashtable with Content, Title, Format and Tags. Converters may return a string, a hashtable or an object with a Content property.

    .PARAMETER Path
        Path of the file to convert to Markdown.

    .PARAMETER Format
        Name of the converter to use instead of detecting it from the file extension.

    .EXAMPLE
        ConvertTo-McpMarkdown -Path ./Handbook.docx

        Converts the Word document and returns Content, Title, Format (Docx) and Tags.

    .OUTPUTS
        A hashtable with Content, Title, Format and Tags.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
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
