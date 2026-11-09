function Get-McpKnowledgeBaseFile {
    <#
    .SYNOPSIS
        Lists the files that make up a knowledge base (metadata, manifest, documents, index),
        with forward-slash relative paths.

    .DESCRIPTION
        Lists the files that make up a knowledge base (knowledgebase.json, manifest.json and the files in documents and index) with their full path and a relative path using forward slashes. Logs, lock and publish state are not included.

    .PARAMETER KbPath
        Directory of the knowledge base whose files are listed.

    .EXAMPLE
        Get-McpKnowledgeBaseFile -KbPath $kb.Path | Select-Object RelativePath

        Lists knowledgebase.json, manifest.json, documents/*.md and index/*.json.
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
