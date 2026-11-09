<#
    Documentation quality tests: the generated cmdlet reference matches the help of the built module,
    the guides are complete and every relative link in the Markdown documentation resolves.
#>
BeforeDiscovery {
    $projectPath = Join-Path -Path $PSScriptRoot -ChildPath '../..' | Convert-Path
    $module = Get-Module -Name 'MCPPosh' -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
    $exportedFunctions = @((Import-PowerShellDataFile -Path $module.Path).FunctionsToExport)

    $script:cmdletCases = @($exportedFunctions | ForEach-Object { @{ Name = $_ } })
    $script:referenceCases = @(Get-ChildItem -Path (Join-Path $projectPath 'docs/en-US') -Filter '*.md' -File |
            ForEach-Object { @{ File = $_.Name; Path = $_.FullName } })
    $markdownFiles = @(Get-ChildItem -Path (Join-Path $projectPath 'docs') -Filter '*.md' -File -Recurse) +
        @(Get-Item -Path (Join-Path $projectPath 'README.md'), (Join-Path $projectPath 'CHANGELOG.md'), (Join-Path $projectPath 'deploy/azure/README.md'))
    $script:markdownCases = @($markdownFiles | ForEach-Object {
            @{ File = [System.IO.Path]::GetRelativePath($projectPath, $_.FullName).Replace('\', '/'); Path = $_.FullName }
        })
    $script:guideCases = @(Get-ChildItem -Path (Join-Path $projectPath 'docs') -Filter '*.md' -File |
            Where-Object Name -NE 'README.md' | ForEach-Object { @{ File = $_.Name } })
}

BeforeAll {
    $projectPath = Join-Path -Path $PSScriptRoot -ChildPath '../..' | Convert-Path
    $docsPath = Join-Path -Path $projectPath -ChildPath 'docs'
    $referencePath = Join-Path -Path $docsPath -ChildPath 'en-US'
    Import-Module -Name 'MCPPosh' -Force -ErrorAction Stop

    function Get-MarkdownLinkTarget {
        param([string] $Content)
        # Ignore fenced code blocks and inline code, then collect the targets of Markdown links.
        $text = [regex]::Replace($Content, '(?ms)^\s*```.*?^\s*```', '')
        $text = [regex]::Replace($text, '`[^`\r\n]*`', '')
        foreach ($match in [regex]::Matches($text, '\]\(([^)\s]+)\)')) { $match.Groups[1].Value }
    }

    function Get-MarkdownAnchor {
        param([string] $Path)
        $content = Get-Content -LiteralPath $Path -Raw
        $content = [regex]::Replace($content, '(?ms)^\s*```.*?^\s*```', '')
        foreach ($match in [regex]::Matches($content, '(?m)^#{1,6}\s+(.+?)\s*$')) {
            $heading = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value) -replace '`', ''
            ($heading.ToLowerInvariant() -replace '[^\p{L}\p{N}\s_-]', '') -replace '\s', '-'
        }
    }
}

Describe 'Cmdlet reference' -Tag 'Documentation' {
    It 'Should have a reference page for <Name>' -ForEach $cmdletCases {
        Test-Path -LiteralPath (Join-Path $referencePath "$Name.md") | Should -BeTrue -Because 'run ./build.ps1 -Tasks build, docs to generate the page'
    }

    It 'Should have a reference page synopsis that matches the help of <Name>' -ForEach $cmdletCases {
        $content = Get-Content -LiteralPath (Join-Path $referencePath "$Name.md") -Raw
        $match = [regex]::Match($content, '(?ms)^## SYNOPSIS\s*\r?\n(.+?)\r?\n\s*\r?\n## ')
        $match.Success | Should -BeTrue
        $pageSynopsis = ($match.Groups[1].Value -replace '\s+', ' ').Trim()
        $helpSynopsis = ((Get-Help -Name $Name).Synopsis -replace '\s+', ' ').Trim()
        $pageSynopsis | Should -Be $helpSynopsis -Because 'the reference is outdated; run ./build.ps1 -Tasks build, docs'
    }

    It 'Should link the online help of <Name> to its reference page' -ForEach $cmdletCases {
        $uri = @((Get-Help -Name $Name).relatedLinks.navigationLink | Where-Object { $_.uri } | Select-Object -First 1).uri
        $uri | Should -Be "https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/$Name.md"
    }

    It 'Should list <Name> on the module page' -ForEach $cmdletCases {
        Get-Content -LiteralPath (Join-Path $referencePath 'MCPPosh.md') -Raw | Should -Match ([regex]::Escape("[$Name]($Name.md)"))
    }

    It 'Should have no placeholders in <File>' -ForEach $referenceCases {
        Get-Content -LiteralPath $Path -Raw | Should -Not -Match '\{\{.*\}\}'
    }
}

Describe 'Guides' -Tag 'Documentation' {
    It 'Should list <File> in docs/README.md' -ForEach $guideCases {
        Get-Content -LiteralPath (Join-Path $docsPath 'README.md') -Raw | Should -Match ([regex]::Escape("]($File)"))
    }
}

Describe 'Markdown links' -Tag 'Documentation' {
    It 'Should only contain resolvable relative links in <File>' -ForEach $markdownCases {
        $directory = Split-Path -Path $Path -Parent
        $broken = foreach ($target in (Get-MarkdownLinkTarget -Content (Get-Content -LiteralPath $Path -Raw))) {
            if ($target -match '^(https?|mailto):' -or $target.StartsWith('#')) { continue }
            $file, $anchor = $target -split '#', 2
            $resolved = Join-Path -Path $directory -ChildPath ([System.Uri]::UnescapeDataString($file))
            if (-not (Test-Path -LiteralPath $resolved)) {
                $target
                continue
            }
            if ($anchor -and $resolved -like '*.md' -and (Get-MarkdownAnchor -Path $resolved) -notcontains $anchor) {
                $target
            }
        }
        $broken | Should -BeNullOrEmpty -Because 'relative links must point to existing files and headings'
    }
}
