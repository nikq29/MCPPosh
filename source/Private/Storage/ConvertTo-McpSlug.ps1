function ConvertTo-McpSlug {
    <#
    .SYNOPSIS
        Creates a URL- and file-name-friendly slug from a text.

    .DESCRIPTION
        Converts a title to lowercase, transliterates German umlauts, removes other diacritics, replaces all other characters with hyphens and limits the result to 48 characters. Returns document when nothing usable remains.

    .PARAMETER Text
        The text to convert, usually the title of a document or the name of a knowledge base.

    .EXAMPLE
        ConvertTo-McpSlug -Text 'VPN: Error 809 & Fixes'

        Returns vpn-error-809-fixes.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [AllowEmptyString()]
        [string] $Text
    )

    $slug = ([string]$Text).ToLowerInvariant().Replace([string][char]0x00E4, 'ae').Replace([string][char]0x00F6, 'oe').Replace([string][char]0x00FC, 'ue').Replace([string][char]0x00DF, 'ss')
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
