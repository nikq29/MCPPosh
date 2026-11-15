<#
    Replaces the Sampler task Create_changelog_release_output (tasks in .build override module tasks of the same name).

    Releases move the [Unreleased] entries of CHANGELOG.md into a version section before the tag is created (see
    docs/development.md), so the tagged commit carries the final changelog. Sampler's task only releases [Unreleased]
    and fails when the section of the built version already exists; this task uses that section instead and otherwise
    behaves like Sampler's task.
#>
param
(
    [Parameter()]
    [System.String]
    $ProjectName = (property ProjectName ''),

    [Parameter()]
    [System.String]
    $SourcePath = (property SourcePath ''),

    [Parameter()]
    [System.String]
    $OutputDirectory = (property OutputDirectory (Join-Path $BuildRoot 'output')),

    [Parameter()]
    [System.String]
    $BuiltModuleSubdirectory = (property BuiltModuleSubdirectory ''),

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $VersionedOutputDirectory = (property VersionedOutputDirectory $true),

    [Parameter()]
    [System.String]
    $ChangelogPath = (property ChangelogPath 'CHANGELOG.md'),

    [Parameter()]
    [System.String]
    $ReleaseNotesPath = (property ReleaseNotesPath (Join-Path $OutputDirectory 'ReleaseNotes.md')),

    [Parameter()]
    [System.String]
    $ModuleVersion = (property ModuleVersion ''),

    [Parameter()]
    [System.Collections.Hashtable]
    $BuildInfo = (property BuildInfo @{ })
)

# Synopsis: Writes output/CHANGELOG.md, output/ReleaseNotes.md and the manifest release notes of the built version.
task Create_changelog_release_output {
    . Set-SamplerTaskVariable

    Import-Module -Name ChangelogManagement -ErrorAction Stop
    $changelogSource = Get-SamplerAbsolutePath -Path $ChangelogPath -RelativeTo $BuildRoot
    $changelogOutputPath = Get-SamplerAbsolutePath -Path 'CHANGELOG.md' -RelativeTo $OutputDirectory

    $release = (Get-ChangelogData -Path $changelogSource).Released | Where-Object -FilterScript { $_.Version -eq $ModuleVersion }
    if ($release) {
        Write-Build DarkGray "`tUsing the section [$ModuleVersion] of '$changelogSource'"
        Copy-Item -LiteralPath $changelogSource -Destination $changelogOutputPath -Force
    }
    else {
        try {
            Update-Changelog -Path $changelogSource -OutputPath $changelogOutputPath -ReleaseVersion $ModuleVersion -LinkMode None -ErrorAction Stop
        }
        catch {
            # For example a build of main right after a release, when [Unreleased] is still empty.
            Write-Build Yellow "`tNo release notes for $ModuleVersion : $($_.Exception.Message)"
            Copy-Item -LiteralPath $changelogSource -Destination $changelogOutputPath -Force
            return
        }
        $release = (Get-ChangelogData -Path $changelogOutputPath).Released | Where-Object -FilterScript { $_.Version -eq $ModuleVersion }
    }
    ConvertFrom-Changelog -Path $changelogOutputPath -Format Release -NoHeader -OutputPath $ReleaseNotesPath -ErrorAction Stop

    if ([string]::IsNullOrEmpty($BuiltModuleManifest) -or -not (Test-Path -LiteralPath $BuiltModuleManifest)) {
        Write-Build Red "No valid manifest found for project '$ProjectName'. Cannot update the release notes."
        return
    }
    # The PowerShell Gallery limits the size of the release notes in the manifest.
    $notes = [string]$release.RawData
    if ($notes.Length -gt 10000) { $notes = $notes.Substring(0, 10000) }
    $manifest = Get-Content -LiteralPath $BuiltModuleManifest -Raw
    if ($manifest -match '#\sReleaseNotes\s?=') {
        [System.IO.File]::WriteAllText($BuiltModuleManifest, ($manifest -replace '#\sReleaseNotes\s?=', '  ReleaseNotes ='), [System.Text.UTF8Encoding]::new($false))
    }
    Import-Module -Name Configuration -ErrorAction Stop
    Update-Manifest -Path $BuiltModuleManifest -PropertyName 'PrivateData.PSData.ReleaseNotes' -Value $notes
}
