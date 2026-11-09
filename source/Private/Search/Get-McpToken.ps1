function Get-McpToken {
    <#
    .SYNOPSIS
        Splits text into normalized search tokens (lowercase, diacritics folded, stop words removed, light stemming).

    .DESCRIPTION
        Splits text into search tokens: lowercase, German sharp s expanded, diacritics removed, words shorter than two characters and English/German stop words dropped, and common suffixes stripped so that singular and plural forms match.

    .PARAMETER Text
        The text to tokenize, for example a document chunk, a heading or a search query.

    .EXAMPLE
        Get-McpToken -Text 'Die Server-Konfigurationen'

        Returns the tokens serv and konfiguration.
    #>
    [CmdletBinding()]
    [OutputType([string[]], [object[]])]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Text
    )

    $tokens = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return , $tokens.ToArray()
    }

    $folded = $Text.ToLowerInvariant().Replace([string][char]0x00DF, 'ss')
    $folded = [regex]::Replace($folded.Normalize([System.Text.NormalizationForm]::FormD), '\p{Mn}+', '')
    $suffixes = $script:McpSuffixes
    $stopWords = $script:McpStopWords

    foreach ($match in [regex]::Matches($folded, '[\p{L}\p{N}]+')) {
        $word = $match.Value
        if ($word.Length -lt 2 -or $stopWords.Contains($word)) {
            continue
        }
        while ($word.Length -ge 5) {
            $stripped = $false
            foreach ($suffix in $suffixes) {
                if ($word.EndsWith($suffix, [System.StringComparison]::Ordinal) -and ($word.Length - $suffix.Length) -ge 3) {
                    $word = $word.Substring(0, $word.Length - $suffix.Length)
                    $stripped = $true
                    break
                }
            }
            if (-not $stripped) { break }
        }
        $tokens.Add($word)
    }
    return , $tokens.ToArray()
}
