function ConvertFrom-McpHtml {
    <#
    .SYNOPSIS
        Converts HTML to Markdown (headings, lists, links, emphasis, code blocks and tables).
    .DESCRIPTION
        A pragmatic, dependency-free converter for documentation pages. It prefers the <main> or
        <article> element when present and drops scripts, styles, navigation and footers.
    #>
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string] $Html,

        [string] $BaseUrl
    )

    $title = $null
    $titleMatch = [regex]::Match($Html, '(?is)<title[^>]*>(.*?)</title>')
    if ($titleMatch.Success) {
        $title = Get-McpHtmlInnerText -Html $titleMatch.Groups[1].Value
    }

    $body = $Html
    foreach ($container in 'main', 'article', 'body') {
        $containerMatch = [regex]::Match($Html, "(?is)<$container\b[^>]*>(.*)</$container>")
        if ($containerMatch.Success) {
            $body = $containerMatch.Groups[1].Value
            break
        }
    }

    $body = [regex]::Replace($body, '(?s)<!--.*?-->', '')
    foreach ($tag in 'script', 'style', 'noscript', 'svg', 'template', 'iframe', 'nav', 'footer', 'form', 'button', 'aside') {
        $body = [regex]::Replace($body, "(?is)<$tag\b[^>]*>.*?</$tag>", '')
    }
    $body = [regex]::Replace($body, '(?is)<(head|header)\b[^>]*>.*?</\1>', {
            param($m)
            # Keep headers that contain headings (often the page title in docs pages).
            if ($m.Value -match '(?i)<h[1-6]\b') { $m.Value -replace '(?is)^<(head|header)\b[^>]*>|</(head|header)>$', '' } else { '' }
        })

    # Protect preformatted blocks before whitespace is collapsed.
    $preBlocks = [System.Collections.Generic.List[string]]::new()
    $body = [regex]::Replace($body, '(?is)<pre\b[^>]*>(.*?)</pre>', {
            param($m)
            $inner = $m.Groups[1].Value
            $language = ''
            $langMatch = [regex]::Match($inner, '(?i)class\s*=\s*"[^"]*(?:language|lang)-([a-z0-9+#-]+)')
            if ($langMatch.Success) { $language = $langMatch.Groups[1].Value }
            $code = [regex]::Replace($inner, '(?i)<br\s*/?>', "`n")
            $code = [regex]::Replace($code, '<[^>]+>', '')
            $code = [System.Net.WebUtility]::HtmlDecode($code).Trim("`r", "`n")
            $preBlocks.Add("$language`n$code")
            "<p>@@MCPPOSHPRE$($preBlocks.Count - 1)@@</p>"
        })

    $tables = [System.Collections.Generic.List[string]]::new()
    $body = [regex]::Replace($body, '(?is)<table\b[^>]*>.*?</table>', {
            param($m)
            $tables.Add((ConvertFrom-McpHtmlTable -TableHtml $m.Value))
            "<p>@@MCPPOSHTABLE$($tables.Count - 1)@@</p>"
        })

    $body = [regex]::Replace($body, '\s+', ' ')

    $body = [regex]::Replace($body, '(?is)<h([1-6])\b[^>]*>(.*?)</h\1>', {
            param($m)
            $level = [int]$m.Groups[1].Value
            "`n`n" + ('#' * $level) + ' ' + (Get-McpHtmlInnerText -Html $m.Groups[2].Value) + "`n`n"
        })
    $body = [regex]::Replace($body, '(?is)<code\b[^>]*>(.*?)</code>', {
            param($m)
            $inner = Get-McpHtmlInnerText -Html $m.Groups[1].Value
            if ($inner) { '`' + $inner + '`' } else { '' }
        })
    $body = [regex]::Replace($body, '(?is)<a\b[^>]*?href\s*=\s*["'']([^"'']*)["''][^>]*>(.*?)</a>', {
            param($m)
            $href = $m.Groups[1].Value
            $text = Get-McpHtmlInnerText -Html $m.Groups[2].Value
            if (-not $text) { return '' }
            if (-not $href -or $href.StartsWith('#') -or $href -match '^(?i)javascript:') { return $text }
            "[$text]($(Resolve-McpUrl -Href ([System.Net.WebUtility]::HtmlDecode($href)) -BaseUrl $BaseUrl))"
        })
    $body = [regex]::Replace($body, '(?is)<(strong|b)\b[^>]*>(.*?)</\1>', '**$2**')
    $body = [regex]::Replace($body, '(?is)<(em|i)\b[^>]*>(.*?)</\1>', '*$2*')
    $body = [regex]::Replace($body, '(?i)<br\s*/?>', "`n")
    $body = [regex]::Replace($body, '(?i)<hr\b[^>]*>', "`n`n---`n`n")
    $body = [regex]::Replace($body, '(?i)<li\b[^>]*>', "`n- ")
    $body = [regex]::Replace($body, '(?i)<blockquote\b[^>]*>', "`n`n> ")
    $body = [regex]::Replace($body, '(?i)</?(p|div|section|ul|ol|dl|dt|dd|blockquote|figure|figcaption|details|summary|header|main|article|li)\b[^>]*>', "`n`n")
    $body = [regex]::Replace($body, '<[^>]+>', '')
    $body = [System.Net.WebUtility]::HtmlDecode($body)

    $lines = foreach ($line in ($body -split "`n")) { $line.Trim() }
    $markdown = ($lines -join "`n")
    $markdown = [regex]::Replace($markdown, '(?m)^- \s*\n+(?=\S)', '- ')
    $markdown = [regex]::Replace($markdown, '\n{3,}', "`n`n")
    $markdown = [regex]::Replace($markdown, '(?m)^(- .*)\n\n(?=- )', "`$1`n")

    $markdown = [regex]::Replace($markdown, '@@MCPPOSHTABLE(\d+)@@', { param($m) $tables[[int]$m.Groups[1].Value].Trim() })
    $markdown = [regex]::Replace($markdown, '@@MCPPOSHPRE(\d+)@@', {
            param($m)
            $block = $preBlocks[[int]$m.Groups[1].Value]
            $newline = $block.IndexOf("`n")
            $language = $block.Substring(0, $newline)
            $code = $block.Substring($newline + 1)
            $fence = Get-McpCodeFence -Text $code
            "$fence$language`n$code`n$fence"
        })
    $markdown = $markdown.Trim()

    if (-not $title) {
        $title = Get-McpMarkdownTitle -Markdown $markdown
    }
    if ($title -and -not (Get-McpMarkdownTitle -Markdown $markdown)) {
        $markdown = "# $title`n`n$markdown"
    }

    @{
        Content = $markdown + "`n"
        Title   = $title
    }
}
