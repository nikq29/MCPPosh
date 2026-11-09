<#
.SYNOPSIS
    Installs the MCPPosh module into the container image (AllUsers scope).
.DESCRIPTION
    Installs MCPPosh with PSResourceGet (part of PowerShell 7.4) from the PowerShell Gallery or from
    the nupkg files in a local folder (built with ./build.ps1 -Tasks pack). When a specific version is
    requested from the Gallery, the installation is retried for a while because a freshly published
    version can take a few minutes until it is available.
.PARAMETER Source
    PSGallery (default) or Local.
.PARAMETER Version
    Version to install, e.g. 0.1.0 or 0.2.0-preview0003. Empty installs the latest stable version.
.PARAMETER PackagePath
    Folder with MCPPosh.<version>.nupkg for -Source Local.
.PARAMETER RetryMinutes
    How long to retry a Gallery installation of a specific version.
.EXAMPLE
    ./Install-MCPPosh.ps1 -Source PSGallery -Version 0.1.0
#>
[CmdletBinding()]
param(
    [ValidateSet('PSGallery', 'Local')]
    [string] $Source = 'PSGallery',

    [AllowEmptyString()]
    [string] $Version = '',

    [string] $PackagePath = '/tmp/install/packages',

    [ValidateRange(0, 60)]
    [int] $RetryMinutes = 10
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
Import-Module -Name Microsoft.PowerShell.PSResourceGet

$installParameters = @{
    Name            = 'MCPPosh'
    Scope           = 'AllUsers'
    TrustRepository = $true
    Quiet           = $true
}
if ($Version) {
    $installParameters['Version'] = $Version
    if ($Version.Contains('-')) { $installParameters['Prerelease'] = $true }
}

if ($Source -eq 'Local') {
    $packages = @(Get-ChildItem -Path $PackagePath -Filter 'MCPPosh.*.nupkg' -ErrorAction SilentlyContinue)
    if ($packages.Count -eq 0) {
        throw "No MCPPosh package found in '$PackagePath'. Run ./build.ps1 -Tasks pack and copy output/MCPPosh.*.nupkg to docker/packages."
    }
    Register-PSResourceRepository -Name 'MCPPoshLocal' -Uri $PackagePath -Trusted
    $installParameters['Repository'] = 'MCPPoshLocal'
    $installParameters['Prerelease'] = $true
    Install-PSResource @installParameters
}
else {
    $installParameters['Repository'] = 'PSGallery'
    $deadline = [datetime]::UtcNow.AddMinutes($RetryMinutes)
    while ($true) {
        try {
            Install-PSResource @installParameters
            break
        }
        catch {
            if (-not $Version -or [datetime]::UtcNow -ge $deadline) { throw }
            Write-Host "MCPPosh $Version is not available in the PowerShell Gallery yet, retrying in 30 seconds..."
            Start-Sleep -Seconds 30
        }
    }
}

Import-Module -Name MCPPosh
$module = Get-Module -Name MCPPosh
Write-Host ("Installed MCPPosh {0} with {1} commands from {2}" -f $module.Version, $module.ExportedFunctions.Count, $Source)
