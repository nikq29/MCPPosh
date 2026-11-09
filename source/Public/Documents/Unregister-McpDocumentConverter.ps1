function Unregister-McpDocumentConverter {
    <#
    .SYNOPSIS
        Removes a custom document converter. Built-in converters cannot be removed.
    .EXAMPLE
        Unregister-McpDocumentConverter -Name Email
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
