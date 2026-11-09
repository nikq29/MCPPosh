function Get-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Lists knowledge bases or gets a specific one.
    .PARAMETER Name
        Name (wildcards allowed) or directory path of a knowledge base. Lists all when omitted.
    .EXAMPLE
        Get-McpKnowledgeBase
    .EXAMPLE
        Get-McpKnowledgeBase -Name Contoso | Format-List
    #>
    [CmdletBinding()]
    [OutputType('MCPPosh.KnowledgeBase')]
    param(
        [Parameter(Position = 0, ValueFromPipelineByPropertyName)]
        [SupportsWildcards()]
        [string[]] $Name = '*'
    )

    process {
        foreach ($entry in $Name) {
            if (Test-McpLooksLikePath -Value $entry) {
                ConvertTo-McpKnowledgeBaseObject -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase $entry)
                continue
            }

            $found = $false
            $directories = Get-ChildItem -LiteralPath (Get-McpKnowledgeBaseRoot) -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -like $entry } | Sort-Object -Property Name
            foreach ($directory in $directories) {
                if (-not (Test-Path -LiteralPath (Join-Path -Path $directory.FullName -ChildPath 'knowledgebase.json'))) { continue }
                $found = $true
                ConvertTo-McpKnowledgeBaseObject -KnowledgeBase (Resolve-McpKnowledgeBase -KnowledgeBase $directory.Name)
            }
            if (-not $found -and -not [System.Management.Automation.WildcardPattern]::ContainsWildcardCharacters($entry)) {
                Write-Error -Message "Knowledge base '$entry' was not found." -Category ObjectNotFound -TargetObject $entry
            }
        }
    }
}
