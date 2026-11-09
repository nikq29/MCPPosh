function Resolve-McpKnowledgeBase {
    <#
    .SYNOPSIS
        Resolves a knowledge base name or directory path to a knowledge base descriptor.
    .DESCRIPTION
        A value that looks like a path (rooted, or containing a slash) is used as the knowledge
        base directory directly, e.g. a mounted Azure Files share. Otherwise the name is looked
        up below $env:MCPPOSH_HOME/knowledgebases.
    #>
    [CmdletBinding()]
    param(
        [string] $KnowledgeBase = 'Default',

        [switch] $CreateIfMissing
    )

    if ([string]::IsNullOrWhiteSpace($KnowledgeBase)) {
        $KnowledgeBase = 'Default'
    }

    if (Test-McpLooksLikePath -Value $KnowledgeBase) {
        $path = [System.IO.Path]::GetFullPath($KnowledgeBase, (Get-Location -PSProvider FileSystem).ProviderPath)
        $name = [System.IO.Path]::GetFileName($path.TrimEnd([char[]]@('/', '\')))
    }
    else {
        if (-not (Test-McpKnowledgeBaseName -Name $KnowledgeBase)) {
            throw "Invalid knowledge base name '$KnowledgeBase'. Use letters, digits, '.', '_' or '-' (max. 64 characters)."
        }
        $path = Join-Path -Path (Get-McpKnowledgeBaseRoot) -ChildPath $KnowledgeBase
        $name = $KnowledgeBase
    }

    $metaPath = Join-Path -Path $path -ChildPath 'knowledgebase.json'
    if (-not (Test-Path -LiteralPath $metaPath -PathType Leaf)) {
        if ($CreateIfMissing) {
            Initialize-McpKnowledgeBaseFolder -Path $path -Name $name
        }
        else {
            throw "Knowledge base '$KnowledgeBase' was not found. Create it with: New-McpKnowledgeBase -Name '$name'"
        }
    }

    $meta = Read-McpJsonFile -Path $metaPath
    [pscustomobject]@{
        Name        = if ($meta.name) { [string]$meta.name } else { $name }
        Path        = $path
        Description = [string]$meta.description
        Created     = $meta.created
    }
}
