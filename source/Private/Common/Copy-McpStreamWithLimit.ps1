function Copy-McpStreamWithLimit {
    <#
    .SYNOPSIS
        Copies a stream to another stream and fails when more than a maximum number of bytes arrive.

    .DESCRIPTION
        Copies the source stream to the destination stream in blocks and counts the bytes that were actually read, independent of any declared length (Content-Length headers, sizes stored in ZIP archives). Throws System.IO.InvalidDataException as soon as more than MaxBytes bytes were read, and System.TimeoutException when TimeoutSeconds is set and the copy does not finish in time. Protects request handling, archive import and document conversion against oversized input, decompression bombs and clients that stop sending. Returns the number of bytes copied.

    .PARAMETER Source
        The stream to read from, for example a request input stream or an opened ZIP entry.

    .PARAMETER Destination
        The stream the data is written to, for example a MemoryStream or a FileStream.

    .PARAMETER MaxBytes
        The maximum number of bytes that may be copied; reading one byte more throws.

    .PARAMETER Description
        Short description of the data used in the error message, for example 'request body'.

    .PARAMETER TimeoutSeconds
        Time in seconds the complete copy may take, for example 30. 0 (default) waits without limit. The limit applies to the whole copy, not to single reads, so a client that sends one byte at a time cannot keep it running.

    .EXAMPLE
        $buffer = [System.IO.MemoryStream]::new()
        Copy-McpStreamWithLimit -Source $request.InputStream -Destination $buffer -MaxBytes 10MB -Description 'request body'

        Reads at most 10 MB of the request body into memory.

    .EXAMPLE
        Copy-McpStreamWithLimit -Source $request.InputStream -Destination $buffer -MaxBytes 10MB -TimeoutSeconds 30 -Description 'request body'

        Same, but throws System.TimeoutException when the client has not sent the complete body after 30 seconds.
    #>
    [CmdletBinding()]
    [OutputType([long])]
    param(
        [Parameter(Mandatory)]
        [System.IO.Stream] $Source,

        [Parameter(Mandatory)]
        [System.IO.Stream] $Destination,

        [Parameter(Mandatory)]
        [ValidateRange(0, [long]::MaxValue)]
        [long] $MaxBytes,

        [string] $Description = 'data',

        [ValidateRange(0, 86400)]
        [int] $TimeoutSeconds = 0
    )

    $buffer = [byte[]]::new(81920)
    $total = 0L
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $limit = [timespan]::FromSeconds($TimeoutSeconds)
    while ($true) {
        if ($TimeoutSeconds -gt 0) {
            # Read asynchronously so a source that stops sending cannot block longer than the deadline.
            $remaining = $limit - $watch.Elapsed
            $pending = if ($remaining -gt [timespan]::Zero) { $Source.ReadAsync($buffer, 0, $buffer.Length) }
            if ($null -eq $pending -or -not $pending.Wait($remaining)) {
                $unit = if ($TimeoutSeconds -eq 1) { 'second' } else { 'seconds' }
                throw [System.TimeoutException]::new("The $Description did not arrive within $TimeoutSeconds $unit.")
            }
            $read = $pending.GetAwaiter().GetResult()
        }
        else {
            $read = $Source.Read($buffer, 0, $buffer.Length)
        }
        if ($read -le 0) { break }
        $total += $read
        if ($total -gt $MaxBytes) {
            throw [System.IO.InvalidDataException]::new("The $Description exceeds the limit of $MaxBytes bytes.")
        }
        $Destination.Write($buffer, 0, $read)
    }
    $total
}
