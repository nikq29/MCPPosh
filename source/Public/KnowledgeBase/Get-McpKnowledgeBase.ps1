function Get-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Lists knowledge bases or gets a specific one.

    .DESCRIPTION
        Lists the knowledge bases below $env:MCPPOSH_HOME (or ~/.mcpposh) or returns a specific one, including the number of documents, characters, tags and the current revision.

    .PARAMETER Name
        Name (wildcards allowed) or directory path of a knowledge base. Lists all when omitted.

    .EXAMPLE
        Get-McpKnowledgeBase

        Lists all knowledge bases with their number of documents and last update.

    .EXAMPLE
        Get-McpKnowledgeBase -Name Contoso | Format-List

        Shows all details of the knowledge base Contoso, including tags, revision and path.

    .INPUTS
        System.String. You can pipe objects with a Name property.

    .OUTPUTS
        MCPPosh.KnowledgeBase: Name, Description, Documents, Characters, Tags, Revision, Created, Updated and Path.

    .LINK
        https://github.com/nikq29/MCPPosh/blob/main/docs/en-US/Get-McpKnowledgeBase.md

    .LINK
        New-McpKnowledgeBase

    .LINK
        Set-McpKnowledgeBase

    .LINK
        Remove-McpKnowledgeBase
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
