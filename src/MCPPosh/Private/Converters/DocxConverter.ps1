Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.ZipFile

function Read-McpZipEntryText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.IO.Compression.ZipArchive] $Archive,

        [Parameter(Mandatory)]
        [string] $EntryName
    )

    $entry = $Archive.GetEntry($EntryName)
    if (-not $entry) { return $null }
    $reader = [System.IO.StreamReader]::new($entry.Open(), [System.Text.Encoding]::UTF8)
    try {
        $reader.ReadToEnd()
    }
    finally {
        $reader.Dispose()
    }
}

function Get-McpDocxParagraphText {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [System.Xml.XmlNode] $Paragraph,

        [Parameter(Mandatory)]
        [System.Xml.XmlNamespaceManager] $Namespaces
    )

    $builder = [System.Text.StringBuilder]::new()
    foreach ($node in $Paragraph.SelectNodes('.//w:t | .//w:tab | .//w:br | .//w:cr', $Namespaces)) {
        switch ($node.LocalName) {
            't' { $null = $builder.Append($node.InnerText) }
            'tab' { $null = $builder.Append(' ') }
            default { $null = $builder.Append("`n") }
        }
    }
    $builder.ToString()
}

function ConvertFrom-McpDocxFile {
    <#
    .SYNOPSIS
        Converts a Word document (.docx) to Markdown using only .NET (no Word installation required).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $documentXml = Read-McpZipEntryText -Archive $archive -EntryName 'word/document.xml'
        if (-not $documentXml) {
            throw "'$Path' is not a valid Word document (word/document.xml is missing)."
        }
        $stylesXml = Read-McpZipEntryText -Archive $archive -EntryName 'word/styles.xml'
        $coreXml = Read-McpZipEntryText -Archive $archive -EntryName 'docProps/core.xml'
    }
    finally {
        $archive.Dispose()
    }

    $wordNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
    $document = [System.Xml.XmlDocument]::new()
    $document.LoadXml($documentXml)
    $ns = [System.Xml.XmlNamespaceManager]::new($document.NameTable)
    $ns.AddNamespace('w', $wordNs)

    # Map style ids to heading levels. Style ids are localized ("Heading1", "berschrift1", ...),
    # but the style *name* is always the English built-in name ("heading 1", "Title").
    $headingLevels = @{}
    if ($stylesXml) {
        $styles = [System.Xml.XmlDocument]::new()
        $styles.LoadXml($stylesXml)
        $styleNs = [System.Xml.XmlNamespaceManager]::new($styles.NameTable)
        $styleNs.AddNamespace('w', $wordNs)
        foreach ($style in $styles.SelectNodes('//w:style[@w:type="paragraph"]', $styleNs)) {
            $styleId = $style.GetAttribute('styleId', $wordNs)
            $nameNode = $style.SelectSingleNode('w:name', $styleNs)
            $styleName = if ($nameNode) { $nameNode.GetAttribute('val', $wordNs) } else { '' }
            if ($styleName -match '^(?i)heading\s*(\d)$') { $headingLevels[$styleId] = [int]$Matches[1] }
            elseif ($styleName -match '^(?i)title$') { $headingLevels[$styleId] = 1 }
        }
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $firstHeading = $null
    $body = $document.SelectSingleNode('/w:document/w:body', $ns)
    foreach ($node in $body.ChildNodes) {
        if ($node.LocalName -eq 'p') {
            $text = (Get-McpDocxParagraphText -Paragraph $node -Namespaces $ns).Trim()
            if (-not $text) { continue }
            $styleNode = $node.SelectSingleNode('w:pPr/w:pStyle', $ns)
            $styleId = if ($styleNode) { $styleNode.GetAttribute('val', $wordNs) } else { '' }
            $level = 0
            if ($styleId -and $headingLevels.ContainsKey($styleId)) { $level = $headingLevels[$styleId] }
            elseif ($styleId -match '^(?i)(heading|berschrift|titre|titulo)(\d)$') { $level = [int]$Matches[2] }
            elseif ($styleId -match '^(?i)title$') { $level = 1 }
            $outline = $node.SelectSingleNode('w:pPr/w:outlineLvl', $ns)
            if ($level -eq 0 -and $outline) { $level = [int]$outline.GetAttribute('val', $wordNs) + 1 }

            if ($level -gt 0) {
                $level = [Math]::Min(6, $level)
                if (-not $firstHeading) { $firstHeading = $text }
                $lines.Add('')
                $lines.Add(('#' * $level) + ' ' + ($text -replace '\s*\n\s*', ' '))
                $lines.Add('')
                continue
            }

            $numbering = $node.SelectSingleNode('w:pPr/w:numPr', $ns)
            if ($numbering) {
                $levelNode = $numbering.SelectSingleNode('w:ilvl', $ns)
                $indent = if ($levelNode) { [int]$levelNode.GetAttribute('val', $wordNs) } else { 0 }
                $lines.Add(('  ' * $indent) + '- ' + ($text -replace '\s*\n\s*', ' '))
                continue
            }

            if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -match '^\s*- ') { $lines.Add('') }
            $lines.Add($text)
            $lines.Add('')
        }
        elseif ($node.LocalName -eq 'tbl') {
            $rows = [System.Collections.Generic.List[string[]]]::new()
            foreach ($row in $node.SelectNodes('w:tr', $ns)) {
                $cells = [System.Collections.Generic.List[string]]::new()
                foreach ($cell in $row.SelectNodes('w:tc', $ns)) {
                    $paragraphs = foreach ($p in $cell.SelectNodes('.//w:p', $ns)) {
                        (Get-McpDocxParagraphText -Paragraph $p -Namespaces $ns).Trim()
                    }
                    $cells.Add((@($paragraphs | Where-Object { $_ }) -join ' '))
                }
                $rows.Add($cells.ToArray())
            }
            if ($rows.Count -gt 0) {
                $lines.Add('')
                $lines.Add((ConvertTo-McpMarkdownTable -Rows $rows.ToArray()).TrimEnd())
                $lines.Add('')
            }
        }
    }

    $title = $null
    if ($coreXml) {
        $titleMatch = [regex]::Match($coreXml, '(?is)<dc:title>(.*?)</dc:title>')
        if ($titleMatch.Success) { $title = [System.Net.WebUtility]::HtmlDecode($titleMatch.Groups[1].Value).Trim() }
    }
    if (-not $title) { $title = $firstHeading }

    $markdown = [regex]::Replace(($lines -join "`n"), '\n{3,}', "`n`n").Trim()
    @{
        Content = $markdown + "`n"
        Title   = $title
    }
}
