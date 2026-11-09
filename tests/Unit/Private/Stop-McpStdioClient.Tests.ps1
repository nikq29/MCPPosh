BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Proto -Description 'Protocol tests' | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Backup' -Content "# Backup`n`nThe nightly backup runs at 02:00 with Veeam." -Tags ops | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Onboarding' -Content ("# Onboarding`n`n" + ('New employees receive their laptop on the first day. ' * 40)) -Tags hr | Out-Null
    $script:Context = New-McpTestContext -KnowledgeBase Proto
    $script:WriteContext = New-McpTestContext -KnowledgeBase Proto -AllowWrite
    $script:KbPath = & (Get-Module MCPPosh) { (Resolve-McpKnowledgeBase -KnowledgeBase Proto).Path }
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Stop-McpStdioClient' {
    It 'stops the process of a stdio client' {
        InModuleScope MCPPosh -Parameters @{ KbPath = $script:KbPath } {
            param($KbPath)
            $client = Start-McpStdioClient -KbPath $KbPath
            $process = $client.Process
            $id = $process.Id
            Stop-McpStdioClient -Client $client
            { [System.Diagnostics.Process]::GetProcessById($id).HasExited } | Should -Not -Be $false
            Get-McpProcessStartTime -ProcessId $id | Should -BeNullOrEmpty
        }
    }
}
