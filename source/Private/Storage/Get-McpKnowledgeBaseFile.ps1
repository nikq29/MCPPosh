function Get-McpKnowledgeBaseFile {
    <#
    .SYNOPSIS
        Lists the files that make up a knowledge base (metadata, manifest, documents, index),
        with forward-slash relative paths.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath
    )

    foreach ($name in 'knowledgebase.json', 'manifest.json') {
        $path = Join-Path -Path $KbPath -ChildPath $name
        if (Test-Path -LiteralPath $path) {
            [pscustomobject]@{ FullPath = $path; RelativePath = $name }
        }
    }
    foreach ($folder in 'documents', 'index') {
        $directory = Join-Path -Path $KbPath -ChildPath $folder
        if (-not (Test-Path -LiteralPath $directory)) { continue }
        foreach ($file in (Get-ChildItem -LiteralPath $directory -File | Where-Object { -not $_.Name.StartsWith('.') } | Sort-Object -Property Name)) {
            [pscustomobject]@{ FullPath = $file.FullName; RelativePath = "$folder/$($file.Name)" }
        }
    }
}
