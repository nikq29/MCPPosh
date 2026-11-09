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
