function New-McpToolResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text,

        [object] $Structured,

        [switch] $IsError
    )

    $result = [ordered]@{
        content = @([ordered]@{ type = 'text'; text = $Text })
    }
    if ($null -ne $Structured) { $result['structuredContent'] = $Structured }
    if ($IsError) { $result['isError'] = $true }
    $result
}
