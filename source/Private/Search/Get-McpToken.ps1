function Get-McpToken {
    <#
    .SYNOPSIS
        Splits text into normalized search tokens (lowercase, diacritics folded, stop words removed, light stemming).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [AllowEmptyString()]
        [AllowNull()]
        [string] $Text
    )

    $tokens = [System.Collections.Generic.List[string]]::new()
    if ([string]::IsNullOrWhiteSpace($Text)) {
        return , $tokens.ToArray()
    }

    $folded = $Text.ToLowerInvariant().Replace('ß', 'ss')
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
