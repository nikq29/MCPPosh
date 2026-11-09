function Register-McpDocumentConverter {
    <#
    .SYNOPSIS
        Registers a custom converter so Add-McpDocument can import additional file formats.

    .DESCRIPTION
        The script block receives the file path and returns either a Markdown string or a
        hashtable with Content (required), Title and Tags. Custom converters take precedence
        over built-in converters for the same extension.

        Registrations last for the current PowerShell session; put them in your profile to make
        them permanent. Running servers do not need the converter: documents are converted when
        they are added.

    .PARAMETER Name
        Name of the converter. It is stored as the document format and can be passed to Add-McpDocument -Format.

    .PARAMETER Extension
        One or more file extensions handled by the converter, with or without the leading dot (for example .eml).

    .PARAMETER ScriptBlock
        Script block that receives the file path and returns Markdown text or a hashtable with Content, Title and Tags.

    .PARAMETER Force
        Replaces an existing custom converter with the same name instead of failing.

    .EXAMPLE
        Register-McpDocumentConverter -Name Pptx -Extension .pptx -ScriptBlock {
            param($Path)
            # use a module of your choice to extract the slide text
            @{ Content = (Get-MySlideText -Path $Path) -join "`n`n"; Title = (Split-Path $Path -LeafBase) }
        }

        Adds support for PowerPoint files. The script block returns a hashtable with the Markdown content and the title.

    .EXAMPLE
        Register-McpDocumentConverter -Name Email -Extension .eml -ScriptBlock { param($Path) Get-Content $Path -Raw }

        Imports e-mail files as plain text. Register converters in your profile to keep them for new sessions.

    .INPUTS
        None. You cannot pipe objects to this cmdlet.

    .OUTPUTS
        MCPPosh.Converter: Name, Extensions, ScriptBlock and Builtin.

    .LINK
        https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Register-McpDocumentConverter.md

    .LINK
        Get-McpDocumentConverter

    .LINK
        Unregister-McpDocumentConverter

    .LINK
        Add-McpDocument
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('MCPPosh.Converter')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidatePattern('^[A-Za-z][A-Za-z0-9_-]*$')]
        [string] $Name,

        [Parameter(Mandatory, Position = 1)]
        [string[]] $Extension,

        [Parameter(Mandatory, Position = 2)]
        [scriptblock] $ScriptBlock,

        [switch] $Force
    )

    $extensions = [string[]]@($Extension | ForEach-Object {
            $value = $_.Trim().ToLowerInvariant()
            if (-not $value.StartsWith('.')) { $value = ".$value" }
            $value
        } | Sort-Object -Unique)

    $existing = $script:McpConverters | Where-Object { $_.Name -eq $Name -and -not $_.Builtin }
    if ($existing -and -not $Force) {
        throw "A custom converter named '$Name' is already registered. Use -Force to replace it."
    }

    if ($PSCmdlet.ShouldProcess($Name, "Register converter for $($extensions -join ', ')")) {
        foreach ($item in @($existing)) { $null = $script:McpConverters.Remove($item) }
        $converter = [pscustomobject]@{
            PSTypeName  = 'MCPPosh.Converter'
            Name        = $Name
            Extensions  = $extensions
            ScriptBlock = $ScriptBlock
            Builtin     = $false
        }
        $script:McpConverters.Add($converter)
        $converter
    }
}
