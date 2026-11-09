BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Register-McpDocumentConverter' {
    AfterEach {
        Get-McpDocumentConverter | Where-Object { -not $_.Builtin } | Unregister-McpDocumentConverter
    }

    It 'registers a converter that Add-McpDocument uses' {
        $converter = Register-McpDocumentConverter -Name Email -Extension 'eml' -ScriptBlock {
            param($Path)
            @{ Content = "# Mail`n`n" + (Get-Content -LiteralPath $Path -Raw); Title = 'A mail'; Tags = 'mail' }
        }
        $converter.Extensions | Should -Be @('.eml')
        $path = Join-Path $script:TestHome 'message.eml'
        Set-Content -Path $path -Value 'Hello world'
        $doc = Add-McpDocument -Path $path
        $doc.Title | Should -Be 'A mail'
        $doc.Format | Should -Be 'Email'
        $doc.Tags | Should -Be @('mail')
    }

    It 'overrides built-in converters for the same extension' {
        Register-McpDocumentConverter -Name UpperText -Extension .txt -ScriptBlock { param($Path) (Get-Content -LiteralPath $Path -Raw).ToUpperInvariant() } | Out-Null
        $path = Join-Path $script:TestHome 'shout.txt'
        Set-Content -Path $path -Value 'quiet'
        (Get-McpDocument -Id (Add-McpDocument -Path $path).Id -IncludeContent).Content.Trim() | Should -Be 'QUIET'
    }

    It 'refuses duplicate names without -Force' {
        Register-McpDocumentConverter -Name Dup -Extension .dup -ScriptBlock { 'x' } | Out-Null
        { Register-McpDocumentConverter -Name Dup -Extension .dup -ScriptBlock { 'y' } } | Should -Throw '*already registered*'
        { Register-McpDocumentConverter -Name Dup -Extension .dup -ScriptBlock { 'y' } -Force } | Should -Not -Throw
    }
}
