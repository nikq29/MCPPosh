<#
    Integration test coverage guard: every exported command, every parameter set and every parameter of MCPPosh
    must be used in an end-to-end test in tests/Integration, and those tests must not use mocks.

    The calls are found in the syntax tree of the test files (including script blocks that run in child processes
    or thread jobs). Use named, full parameter names in integration tests; positional arguments, pipeline input and
    splatting are not counted.
#>
BeforeDiscovery {
    $module = Get-Module -Name 'MCPPosh' -ListAvailable | Sort-Object -Property Version -Descending | Select-Object -First 1
    Import-Module -Name $module.Path -Force -ErrorAction Stop
    $common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
    $commands = @(Get-Command -Module 'MCPPosh' -CommandType Function | Sort-Object -Property Name)

    $script:commandCases = @($commands | ForEach-Object { @{ Name = $_.Name } })
    $script:parameterSetCases = @(foreach ($command in $commands) {
            foreach ($set in $command.ParameterSets) { @{ Name = $command.Name; ParameterSet = $set.Name } }
        })
    $script:parameterCases = @(foreach ($command in $commands) {
            foreach ($parameter in $command.Parameters.Values) {
                if ($parameter.Name -in $common) { continue }
                $hidden = @($parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.DontShow }).Count -gt 0
                if ($hidden) { continue }
                @{ Name = $command.Name; Parameter = $parameter.Name }
            }
        })
}

BeforeAll {
    $projectPath = Join-Path -Path $PSScriptRoot -ChildPath '../..' | Convert-Path
    $integrationFiles = @(Get-ChildItem -Path (Join-Path -Path $projectPath -ChildPath 'tests/Integration') -Filter '*.Tests.ps1' -File)
    $common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
    $commands = @{}
    Get-Command -Module 'MCPPosh' -CommandType Function | ForEach-Object { $commands[$_.Name] = $_ }

    function Resolve-ParameterName {
        <# Returns the full parameter name for a (possibly abbreviated) name or alias, or $null. #>
        param([System.Management.Automation.CommandInfo] $Command, [string] $Name)
        $exact = @($Command.Parameters.Values | Where-Object { $_.Name -eq $Name -or $_.Aliases -contains $Name })
        if ($exact.Count -eq 1) { return $exact[0].Name }
        $prefix = @($Command.Parameters.Values | Where-Object { $_.Name -like "$Name*" })
        if ($prefix.Count -eq 1) { return $prefix[0].Name }
        $null
    }

    function Resolve-ParameterSet {
        <# Returns the parameter set PowerShell binds for the named parameters of a call, or $null if ambiguous. #>
        param([System.Management.Automation.CommandInfo] $Command, [string[]] $Used)
        $candidates = @($Command.ParameterSets | Where-Object {
                $names = @($_.Parameters.Name) + $common
                @($Used | Where-Object { $names -notcontains $_ }).Count -eq 0
            })
        if ($candidates.Count -gt 1) {
            $complete = @($candidates | Where-Object {
                    $mandatory = @($_.Parameters | Where-Object IsMandatory | ForEach-Object Name)
                    @($mandatory | Where-Object { $Used -notcontains $_ }).Count -eq 0
                })
            if ($complete.Count -gt 0) { $candidates = $complete }
        }
        if ($candidates.Count -gt 1) {
            $default = @($candidates | Where-Object IsDefault)
            if ($default.Count -eq 1) { $candidates = $default }
        }
        if ($candidates.Count -eq 1) { $candidates[0].Name } else { $null }
    }

    $script:Calls = @(foreach ($file in $integrationFiles) {
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref] $tokens, [ref] $errors)
            foreach ($commandAst in $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] }, $true)) {
                $name = $commandAst.GetCommandName()
                if (-not $name) { continue }
                $command = $commands[$name]
                $used = @()
                $parameterSet = $null
                if ($command) {
                    $used = @($commandAst.CommandElements |
                            Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } |
                            ForEach-Object { Resolve-ParameterName -Command $command -Name $_.ParameterName } |
                            Where-Object { $_ })
                    $parameterSet = Resolve-ParameterSet -Command $command -Used $used
                }
                [pscustomobject]@{
                    Name         = $name
                    Parameters   = $used
                    ParameterSet = $parameterSet
                    Location     = '{0}:{1}' -f $file.Name, $commandAst.Extent.StartLineNumber
                }
            }
        })
}

Describe 'Integration test coverage' -Tag 'IntegrationCoverage' {
    It 'Should call <Name> in an integration test' -ForEach $commandCases {
        @($Calls | Where-Object Name -EQ $Name).Count | Should -BeGreaterThan 0 -Because "every command needs an end-to-end test in tests/Integration"
    }

    It 'Should cover the parameter set <ParameterSet> of <Name>' -ForEach $parameterSetCases {
        @($Calls | Where-Object { $_.Name -eq $Name -and $_.ParameterSet -eq $ParameterSet }).Count |
            Should -BeGreaterThan 0 -Because 'every parameter set needs an end-to-end test with named parameters in tests/Integration'
    }

    It 'Should use the parameter -<Parameter> of <Name>' -ForEach $parameterCases {
        @($Calls | Where-Object { $_.Name -eq $Name -and $_.Parameters -contains $Parameter }).Count |
            Should -BeGreaterThan 0 -Because 'every parameter needs an end-to-end test in tests/Integration'
    }

    It 'Should not use Mock in integration tests' {
        @($Calls | Where-Object Name -EQ 'Mock' | ForEach-Object Location) | Should -BeNullOrEmpty -Because 'integration tests run the real module'
    }
}
