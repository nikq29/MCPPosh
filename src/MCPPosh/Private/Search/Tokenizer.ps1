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

# Light, language-agnostic (German/English) suffix stripping. Applied repeatedly so that
# e.g. "servers" -> "server" -> "serv" and "server" -> "serv" end up identical.
$script:McpSuffixes = [string[]]@('ungen', 'heiten', 'keiten', 'ingen', 'ung', 'heit', 'keit', 'ing', 'ies', 'ern', 'en', 'er', 'es', 'ed', 'e', 's')

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
