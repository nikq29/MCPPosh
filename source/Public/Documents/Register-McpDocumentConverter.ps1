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
    .EXAMPLE
        Register-McpDocumentConverter -Name Pptx -Extension .pptx -ScriptBlock {
            param($Path)
            # e.g. use a module of your choice to extract slide text
            @{ Content = (Get-MySlideText -Path $Path) -join "`n`n"; Title = (Split-Path $Path -LeafBase) }
        }
    .EXAMPLE
        Register-McpDocumentConverter -Name Email -Extension .eml -ScriptBlock { param($Path) Get-Content $Path -Raw }
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
