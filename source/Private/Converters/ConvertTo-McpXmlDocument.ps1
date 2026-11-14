function ConvertTo-McpXmlDocument {
    <#
    .SYNOPSIS
        Parses untrusted XML text into an XmlDocument without processing document type definitions.

    .DESCRIPTION
        Parses XML text from imported files (for example the parts of a Word document) with DTD processing prohibited and no XML resolver, so entity expansion ("billion laughs") and external entities cannot be used. Documents that contain a DTD, and malformed XML, are rejected with System.IO.InvalidDataException.

    .PARAMETER Xml
        The XML text to parse, for example the content of word/document.xml.

    .PARAMETER Description
        Name of the XML source used in error messages, for example "'handbook.docx' (word/document.xml)".

    .EXAMPLE
        $document = ConvertTo-McpXmlDocument -Xml $documentXml -Description "'handbook.docx' (word/document.xml)"

        Returns the parsed System.Xml.XmlDocument.
    #>
    [CmdletBinding()]
    [OutputType([System.Xml.XmlDocument])]
    param(
        [Parameter(Mandatory)]
        [string] $Xml,

        [string] $Description = 'XML document'
    )

    $settings = [System.Xml.XmlReaderSettings]::new()
    $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
    $settings.XmlResolver = $null
    $document = [System.Xml.XmlDocument]::new()
    $document.XmlResolver = $null
    $reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]::new($Xml), $settings)
    try {
        $document.Load($reader)
    }
    catch [System.Xml.XmlException] {
        $reason = if ($_.Exception.Message -match '\bDTD\b') {
            'it contains a document type definition (DTD), which is not allowed for security reasons'
        }
        else {
            $_.Exception.Message
        }
        throw [System.IO.InvalidDataException]::new("$Description could not be read as XML: $reason", $_.Exception)
    }
    finally {
        $reader.Dispose()
    }
    # An XmlDocument is enumerable: without -NoEnumerate the pipeline would return its child nodes.
    Write-Output -InputObject $document -NoEnumerate
}
