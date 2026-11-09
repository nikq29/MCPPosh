BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Source -Description 'Source' | Out-Null
    Add-McpDocument -KnowledgeBase Source -Title 'One' -Content "# One`n`nFirst content about certificates." | Out-Null
    $script:Zip = Join-Path $script:TestHome 'source.zip'
    Export-McpKnowledgeBase -Name Source -DestinationPath $script:Zip | Out-Null
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Import-McpKnowledgeBase' {
    It 'imports an archive under a new name' {
        $kb = Import-McpKnowledgeBase -Path $script:Zip -Name Copy
        $kb.Name | Should -Be 'Copy'
        $kb.Documents | Should -Be 1
        $kb.Description | Should -Be 'Source'
        (Search-McpDocument -KnowledgeBase Copy -Query 'certificates')[0].Title | Should -Be 'One'
    }

    It 'refuses to replace an existing knowledge base without -Force' {
        { Import-McpKnowledgeBase -Path $script:Zip } | Should -Throw '*already exists*'
        (Import-McpKnowledgeBase -Path $script:Zip -Name Copy -Force -Confirm:$false).Name | Should -Be 'Copy'
    }

    It 'rejects archives that are not knowledge bases' {
        $folder = Join-Path $script:TestHome 'bogus'
        New-Item -ItemType Directory -Path $folder -Force | Out-Null
        Set-Content -Path (Join-Path $folder 'readme.txt') -Value 'hi'
        $bogus = Join-Path $script:TestHome 'bogus.zip'
        Compress-Archive -Path (Join-Path $folder '*') -DestinationPath $bogus
        { Import-McpKnowledgeBase -Path $bogus -Name Bogus } | Should -Throw '*not an MCPPosh knowledge base*'
        Get-McpKnowledgeBase -Name Bogus -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'fails for missing archives' {
        { Import-McpKnowledgeBase -Path (Join-Path $script:TestHome 'missing.zip') } | Should -Throw '*was not found*'
    }
}
