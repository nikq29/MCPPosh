BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Source -Description 'Source' | Out-Null
    Add-McpDocument -KnowledgeBase Source -Title 'One' -Content "# One`n`nFirst content about certificates." | Out-Null
    Add-McpDocument -KnowledgeBase Source -Title 'Two' -Content "# Two`n`nSecond content." | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Export-McpKnowledgeBase' {
    It 'exports metadata, manifest, documents and index but no logs' {
        $zip = Join-Path $script:TestHome 'source.zip'
        $file = Export-McpKnowledgeBase -Name Source -DestinationPath $zip
        $file.Length | Should -BeGreaterThan 0
        $archive = [System.IO.Compression.ZipFile]::OpenRead($zip)
        try { $entries = @($archive.Entries.FullName) } finally { $archive.Dispose() }
        $entries | Should -Contain 'manifest.json'
        $entries | Should -Contain 'knowledgebase.json'
        @($entries | Where-Object { $_ -like 'documents/*' }).Count | Should -Be 2
        @($entries | Where-Object { $_ -like 'index/*' }).Count | Should -Be 2
        $entries | Where-Object { $_ -like 'logs/*' -or $_ -like '*.lock' } | Should -BeNullOrEmpty
    }

    It 'refuses to overwrite without -Force' {
        $zip = Join-Path $script:TestHome 'source.zip'
        { Export-McpKnowledgeBase -Name Source -DestinationPath $zip } | Should -Throw '*already exists*'
        { Export-McpKnowledgeBase -Name Source -DestinationPath $zip -Force } | Should -Not -Throw
    }
}
