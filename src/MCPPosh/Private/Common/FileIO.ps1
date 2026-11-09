$script:Utf8NoBom = [System.Text.UTF8Encoding]::new($false)

function Read-McpTextFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $attempt = 0
    while ($true) {
        try {
            # ReadAllText detects and strips a BOM; UTF-8 is the fallback.
            return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        }
        catch [System.IO.IOException] {
            if (++$attempt -ge 20) { throw }
            Start-Sleep -Milliseconds 50
        }
    }
}

function Write-McpTextFile {
    <#
    .SYNOPSIS
        Atomically writes UTF-8 text (no BOM): write to a temp file, then rename over the target.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Content
    )

    $directory = [System.IO.Path]::GetDirectoryName($Path)
    if (-not [System.IO.Directory]::Exists($directory)) {
        $null = [System.IO.Directory]::CreateDirectory($directory)
    }
    $tempPath = [System.IO.Path]::Combine($directory, ('.{0}.{1}.tmp' -f [System.IO.Path]::GetFileName($Path), [guid]::NewGuid().ToString('N')))
    [System.IO.File]::WriteAllText($tempPath, $Content, $script:Utf8NoBom)

    $attempt = 0
    while ($true) {
        try {
            [System.IO.File]::Move($tempPath, $Path, $true)
            break
        }
        catch [System.IO.IOException], [System.UnauthorizedAccessException] {
            if (++$attempt -ge 40) {
                Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
                throw
            }
            Start-Sleep -Milliseconds 50
        }
    }
}

function Invoke-McpKnowledgeBaseLock {
    <#
    .SYNOPSIS
        Runs a script block while holding an exclusive lock on a knowledge base.
    .DESCRIPTION
        The PowerShell session and a running server (add_note tool) may write to the same
        knowledge base concurrently. The lock serializes manifest updates across processes.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $KbPath,

        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [int] $TimeoutSeconds = 30
    )

    $mcpLockFile = [System.IO.Path]::Combine($KbPath, '.lock')
    $mcpLockWatch = [System.Diagnostics.Stopwatch]::StartNew()
    $mcpLockStream = $null
    while ($null -eq $mcpLockStream) {
        try {
            $mcpLockStream = [System.IO.File]::Open($mcpLockFile, [System.IO.FileMode]::OpenOrCreate, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        }
        catch [System.IO.IOException], [System.UnauthorizedAccessException] {
            if ($mcpLockWatch.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                throw "Timed out after $TimeoutSeconds seconds waiting for the lock on knowledge base '$KbPath'."
            }
            Start-Sleep -Milliseconds 100
        }
    }
    try {
        & $ScriptBlock
    }
    finally {
        $mcpLockStream.Dispose()
    }
}

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

function Get-McpUtcNow {
    [System.DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ss.fffZ', [System.Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-McpDateTime {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object] $Value
    )

    if ($null -eq $Value -or $Value -eq '') { return $null }
    if ($Value -is [datetime]) { return $Value }
    [datetime]::Parse([string]$Value, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal)
}
