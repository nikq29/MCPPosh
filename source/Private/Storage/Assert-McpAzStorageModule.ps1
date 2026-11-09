function Assert-McpAzStorageModule {
    <#
    .SYNOPSIS
        Makes sure the Az.Storage module is available.

    .DESCRIPTION
        Imports the Az.Storage module when its cmdlets are not loaded yet and throws an error with installation instructions when the module is not installed. Used by Publish-McpKnowledgeBase.

    .EXAMPLE
        Assert-McpAzStorageModule

        Returns nothing when Az.Storage is available, otherwise throws an error.
    #>
    [CmdletBinding()]
    param()

    if (-not (Get-Command -Name 'Set-AzStorageFileContent' -ErrorAction SilentlyContinue)) {
        if (-not (Get-Module -ListAvailable -Name 'Az.Storage')) {
            throw "Publish-McpKnowledgeBase requires the Az.Storage module. Install it with: Install-Module Az.Storage -Scope CurrentUser"
        }
        Import-Module -Name 'Az.Storage' -ErrorAction Stop -Verbose:$false
    }
}
