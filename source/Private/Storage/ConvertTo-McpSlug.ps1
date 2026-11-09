function ConvertTo-McpSlug {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Text
    )

    $slug = ([string]$Text).ToLowerInvariant().Replace('ä', 'ae').Replace('ö', 'oe').Replace('ü', 'ue').Replace('ß', 'ss')
    $slug = [regex]::Replace($slug.Normalize([System.Text.NormalizationForm]::FormD), '\p{Mn}+', '')
    $slug = [regex]::Replace($slug, '[^a-z0-9]+', '-').Trim('-')
    if ($slug.Length -gt 48) {
        $slug = $slug.Substring(0, 48).Trim('-')
    }
    if (-not $slug) {
        $slug = 'document'
    }
    $slug
}
