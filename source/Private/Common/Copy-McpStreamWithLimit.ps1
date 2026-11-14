function Copy-McpStreamWithLimit {
    <#
    .SYNOPSIS
        Copies a stream to another stream and fails when more than a maximum number of bytes arrive.

    .DESCRIPTION
        Copies the source stream to the destination stream in blocks and counts the bytes that were actually read, independent of any declared length (Content-Length headers, sizes stored in ZIP archives). Throws System.IO.InvalidDataException as soon as more than MaxBytes bytes were read. Protects request handling, archive import and document conversion against oversized input and decompression bombs. Returns the number of bytes copied.

    .PARAMETER Source
        The stream to read from, for example a request input stream or an opened ZIP entry.

    .PARAMETER Destination
        The stream the data is written to, for example a MemoryStream or a FileStream.

    .PARAMETER MaxBytes
        The maximum number of bytes that may be copied; reading one byte more throws.

    .PARAMETER Description
        Short description of the data used in the error message, for example 'request body'.

    .EXAMPLE
        $buffer = [System.IO.MemoryStream]::new()
        Copy-McpStreamWithLimit -Source $request.InputStream -Destination $buffer -MaxBytes 10MB -Description 'request body'

        Reads at most 10 MB of the request body into memory.
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

        [string] $Description = 'data'
    )

    $buffer = [byte[]]::new(81920)
    $total = 0L
    while (($read = $Source.Read($buffer, 0, $buffer.Length)) -gt 0) {
        $total += $read
        if ($total -gt $MaxBytes) {
            throw [System.IO.InvalidDataException]::new("The $Description exceeds the limit of $MaxBytes bytes.")
        }
        $Destination.Write($buffer, 0, $read)
    }
    $total
}
