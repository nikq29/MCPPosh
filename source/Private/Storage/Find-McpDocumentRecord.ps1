function Find-McpDocumentRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]] $Documents,

        [string] $Id,

        [string] $SourceType,

        [string] $Source,

        [string] $Title
    )

    foreach ($doc in $Documents) {
        if ($Id) {
            if ($doc.id -eq $Id) { return $doc }
            continue
        }
        if ($SourceType -in 'File', 'Url' -and $Source) {
            if ($doc.sourceType -eq $SourceType -and $doc.source -eq $Source) { return $doc }
            continue
        }
        if ($SourceType -in 'Inline', 'Agent' -and $Title) {
            if ($doc.sourceType -eq $SourceType -and $doc.title -eq $Title) { return $doc }
        }
    }
    $null
}
