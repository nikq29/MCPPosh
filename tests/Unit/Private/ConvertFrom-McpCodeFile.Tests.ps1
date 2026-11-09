BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    $script:Files = Join-Path $script:TestHome 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertFrom-McpCodeFile' {
    It 'wraps scripts in a code block with the detected language' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'deploy.ps1'
            Set-Content -Path $path -Value 'Write-Output "deploy"'
            $result = ConvertFrom-McpCodeFile -Path $path
            $result.Title | Should -Be 'deploy.ps1'
            $result.Format | Should -Be 'Code'
            $result.Content | Should -Match '(?s)^# deploy\.ps1\n\n```powershell\nWrite-Output "deploy"\n```'
        }
    }

    It 'uses a longer fence for code that contains fences and well-known file names' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'readme.py'
            Set-Content -Path $path -Value "x = 1`n``````python`ny = 2`n``````"
            (ConvertFrom-McpCodeFile -Path $path).Content | Should -Match '(?m)^````python$'
            $docker = Join-Path $Files 'Dockerfile'
            Set-Content -Path $docker -Value 'FROM scratch'
            (ConvertFrom-McpCodeFile -Path $docker).Content | Should -Match '```dockerfile'
        }
    }

    It 'accepts an explicit language and format' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files } {
            param($Files)
            $path = Join-Path $Files 'settings.json'
            Set-Content -Path $path -Value '{ "port": 8080 }'
            $result = ConvertFrom-McpCodeFile -Path $path -Language json -Format Json
            $result.Format | Should -Be 'Json'
            $result.Content | Should -Match '```json'
        }
    }
}
