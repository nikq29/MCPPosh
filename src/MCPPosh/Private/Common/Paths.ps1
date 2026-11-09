function Get-McpHomePath {
    <#
    .SYNOPSIS
        Returns the MCPPosh data directory ($env:MCPPOSH_HOME or ~/.mcpposh) and creates it if needed.
    #>
    [CmdletBinding()]
    param()

    $path = if ($env:MCPPOSH_HOME) {
        $env:MCPPOSH_HOME
    }
    else {
        Join-Path -Path ([System.Environment]::GetFolderPath('UserProfile')) -ChildPath '.mcpposh'
    }
    $path = [System.IO.Path]::GetFullPath($path)
    if (-not [System.IO.Directory]::Exists($path)) {
        $null = [System.IO.Directory]::CreateDirectory($path)
    }
    $path
}

function Get-McpKnowledgeBaseRoot {
    [CmdletBinding()]
    param()

    $path = Join-Path -Path (Get-McpHomePath) -ChildPath 'knowledgebases'
    if (-not [System.IO.Directory]::Exists($path)) {
        $null = [System.IO.Directory]::CreateDirectory($path)
    }
    $path
}

function Get-McpServerStateRoot {
    [CmdletBinding()]
    param()

    $path = Join-Path -Path (Get-McpHomePath) -ChildPath 'servers'
    if (-not [System.IO.Directory]::Exists($path)) {
        $null = [System.IO.Directory]::CreateDirectory($path)
    }
    $path
}

function Test-McpKnowledgeBaseName {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Name
    )

    $Name -match '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
}

function Test-McpLooksLikePath {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string] $Value
    )

    [System.IO.Path]::IsPathRooted($Value) -or $Value.Contains('/') -or $Value.Contains('\') -or $Value.StartsWith('.')
}

function Initialize-McpKnowledgeBaseFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Name,

        [AllowEmptyString()]
        [string] $Description = ''
    )

    foreach ($sub in '', 'documents', 'index', 'logs') {
        $dir = if ($sub) { Join-Path -Path $Path -ChildPath $sub } else { $Path }
        if (-not [System.IO.Directory]::Exists($dir)) {
            $null = [System.IO.Directory]::CreateDirectory($dir)
        }
    }

    $now = Get-McpUtcNow
    $metaPath = Join-Path -Path $Path -ChildPath 'knowledgebase.json'
    if (-not (Test-Path -LiteralPath $metaPath)) {
        Write-McpJsonFile -Path $metaPath -InputObject ([ordered]@{
                schemaVersion = 1
                name          = $Name
                description   = $Description
                created       = $now
            })
    }
    $manifestPath = Join-Path -Path $Path -ChildPath 'manifest.json'
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        Write-McpJsonFile -Path $manifestPath -InputObject ([ordered]@{
                schemaVersion = 1
                revision      = 0
                updated       = $now
                documents     = @()
            })
    }
}

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
