function Unregister-McpDocumentConverter {
    <#
    .SYNOPSIS
        Removes a custom document converter. Built-in converters cannot be removed.

    .DESCRIPTION
        Removes a custom converter that was registered with Register-McpDocumentConverter in the current session. Built-in converters cannot be removed.

    .PARAMETER Name
        Name of the custom converter to remove. Accepts the Name property of converter objects through the pipeline.

    .EXAMPLE
        Unregister-McpDocumentConverter -Name Email

        Removes the custom converter Email from the current session.

    .INPUTS
        MCPPosh.Converter. You can pipe converters from Get-McpDocumentConverter.

    .OUTPUTS
        None.

    .LINK
        https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Unregister-McpDocumentConverter.md

    .LINK
        Register-McpDocumentConverter

    .LINK
        Get-McpDocumentConverter
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
        [string] $Name
    )

    process {
        $custom = @($script:McpConverters | Where-Object { $_.Name -eq $Name -and -not $_.Builtin })
        if ($custom.Count -eq 0) {
            Write-Error -Message "No custom converter named '$Name' is registered." -Category ObjectNotFound -TargetObject $Name
            return
        }
        if ($PSCmdlet.ShouldProcess($Name, 'Unregister converter')) {
            foreach ($item in $custom) { $null = $script:McpConverters.Remove($item) }
        }
    }
}
