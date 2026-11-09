function Assert-McpAzStorageModule {
    [CmdletBinding()]
    param()

    if (-not (Get-Command -Name 'Set-AzStorageFileContent' -ErrorAction SilentlyContinue)) {
        if (-not (Get-Module -ListAvailable -Name 'Az.Storage')) {
            throw "Publish-McpKnowledgeBase requires the Az.Storage module. Install it with: Install-Module Az.Storage -Scope CurrentUser"
        }
        Import-Module -Name 'Az.Storage' -ErrorAction Stop -Verbose:$false
    }
}
