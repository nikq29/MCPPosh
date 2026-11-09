function Get-McpSha256 {
    <#
    .SYNOPSIS
        Computes the SHA-256 hash of a text or a file.

    .DESCRIPTION
        Computes the SHA-256 hash of a string (UTF-8 encoded) or of a file and returns it as a lowercase hexadecimal string. Used to detect changed documents and source files.

    .PARAMETER Text
        The text to hash. It is encoded as UTF-8 without byte order mark before hashing.

    .PARAMETER Path
        Path of the file to hash. The file is read as a stream, so large files are supported.

    .EXAMPLE
        Get-McpSha256 -Text 'hello'

        Returns 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824.

    .EXAMPLE
        Get-McpSha256 -Path ./docs/install.md

        Returns the hash of the file content.
    #>
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
