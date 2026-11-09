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
