function Get-McpSha256 {
    [CmdletBinding(DefaultParameterSetName = 'Text')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Text')]
        [AllowEmptyString()]
        [string] $Text,

        [Parameter(Mandatory, ParameterSetName = 'File')]
        [string] $Path
    )

    if ($PSCmdlet.ParameterSetName -eq 'File') {
        $stream = [System.IO.File]::OpenRead($Path)
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $bytes = $sha.ComputeHash($stream)
        }
        finally {
            $sha.Dispose()
            $stream.Dispose()
        }
    }
    else {
        $bytes = [System.Security.Cryptography.SHA256]::HashData($script:Utf8NoBom.GetBytes($Text))
    }
    [System.Convert]::ToHexString($bytes).ToLowerInvariant()
}
