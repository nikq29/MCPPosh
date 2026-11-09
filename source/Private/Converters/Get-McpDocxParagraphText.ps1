function Get-McpDocxParagraphText {
    <#
    .SYNOPSIS
        Returns the text of a Word paragraph.

    .DESCRIPTION
        Concatenates the text runs of a Word (.docx) paragraph element in document order, including text in hyperlinks, and converts tabs and line breaks.

    .PARAMETER Paragraph
        The w:p element of the Word document whose text is returned.

    .PARAMETER Namespaces
        Namespace manager that maps the prefix w to the WordprocessingML namespace.

    .EXAMPLE
        Get-McpDocxParagraphText -Paragraph $paragraph -Namespaces $namespaceManager

        Returns the plain text of the paragraph.
    #>
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
