BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    New-McpKnowledgeBase -Name Proto -Description 'Protocol tests' | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Backup' -Content "# Backup`n`nThe nightly backup runs at 02:00 with Veeam." -Tags ops | Out-Null
    Add-McpDocument -KnowledgeBase Proto -Title 'Onboarding' -Content ("# Onboarding`n`n" + ('New employees receive their laptop on the first day. ' * 40)) -Tags hr | Out-Null
    $script:Context = New-McpTestContext -KnowledgeBase Proto
    $script:WriteContext = New-McpTestContext -KnowledgeBase Proto -AllowWrite
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'Invoke-McpHttpRequest' {
    BeforeAll {
        $script:Port = InModuleScope MCPPosh { Get-McpFreePort }
        $script:Listener = [System.Net.HttpListener]::new()
        $script:Listener.Prefixes.Add("http://localhost:$($script:Port)/")
        $script:Listener.Start()
        $script:Base = "http://localhost:$($script:Port)"

        function Invoke-TestHttp {
            param([string] $Path, [string] $Method = 'GET', [string] $Body, [hashtable] $Headers = @{}, [string[]] $ApiKeys = @('k1'), [string[]] $AllowedOrigins = @(), [string] $ContentType = 'application/json', [switch] $Chunked)
            $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::new($Method), "$($script:Base)$Path")
            foreach ($h in $Headers.GetEnumerator()) { $null = $request.Headers.TryAddWithoutValidation($h.Key, [string]$h.Value) }
            if ($Body) { $request.Content = [System.Net.Http.StringContent]::new($Body, [System.Text.Encoding]::UTF8, $ContentType) }
            if ($Chunked) { $request.Headers.TransferEncodingChunked = $true }
            $client = [System.Net.Http.HttpClient]::new()
            $pending = $client.SendAsync($request)
            $httpContext = $script:Listener.GetContext()
            $settings = @{ ApiKeys = $ApiKeys; AllowedOrigins = $AllowedOrigins; IsLoopback = $true }
            $status = InModuleScope MCPPosh -Parameters @{ Context = $script:Context; HttpContext = $httpContext; Settings = $settings } {
                param($Context, $HttpContext, $Settings)
                Invoke-McpHttpRequest -Context $Context -HttpContext $HttpContext -Settings $Settings
            }
            $httpContext.Response.Close()
            $response = $pending.GetAwaiter().GetResult()
            [pscustomobject]@{ Status = $status; Code = [int]$response.StatusCode; Body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult(); Headers = $response.Headers; Content = $response.Content.Headers }
        }
    }

    AfterAll {
        $script:Listener.Stop()
        $script:Listener.Close()
    }

    It 'serves the root page and the health endpoint' {
        (Invoke-TestHttp -Path '/').Body | Should -Match 'Streamable HTTP'
        $health = (Invoke-TestHttp -Path '/health').Body | ConvertFrom-Json
        $health.status | Should -Be 'ok'
        $health.PSObject.Properties.Name | Should -Not -Contain 'documents'
        ((Invoke-TestHttp -Path '/health' -Headers @{ Authorization = 'Bearer k1' }).Body | ConvertFrom-Json).documents | Should -Be 2
        (Invoke-TestHttp -Path '/health' -Method POST).Code | Should -Be 405
        (Invoke-TestHttp -Path '/missing').Code | Should -Be 404
    }

    It 'requires the API key and handles JSON-RPC over POST' {
        $ping = '{"jsonrpc":"2.0","id":1,"method":"ping"}'
        $unauthorized = Invoke-TestHttp -Path '/mcp' -Method POST -Body $ping
        $unauthorized.Code | Should -Be 401
        $unauthorized.Headers.WwwAuthenticate.ToString() | Should -Match 'Bearer'
        $ok = Invoke-TestHttp -Path '/mcp' -Method POST -Body $ping -Headers @{ 'X-API-Key' = 'k1' }
        $ok.Code | Should -Be 200
        ($ok.Body | ConvertFrom-Json).id | Should -Be 1
        (Invoke-TestHttp -Path '/mcp' -Method POST -Body '{"jsonrpc":"2.0","method":"notifications/initialized"}' -Headers @{ Authorization = 'Bearer k1' }).Code | Should -Be 202
        (Invoke-TestHttp -Path '/mcp' -Headers @{ Authorization = 'Bearer k1' }).Code | Should -Be 405
    }

    It 'requires a JSON content type' {
        $ping = '{"jsonrpc":"2.0","id":1,"method":"ping"}'
        (Invoke-TestHttp -Path '/mcp' -Method POST -Body $ping -ContentType 'text/plain' -Headers @{ Authorization = 'Bearer k1' }).Code | Should -Be 415
        (Invoke-TestHttp -Path '/mcp' -Method POST -Body $ping -ContentType 'application/x-www-form-urlencoded' -Headers @{ Authorization = 'Bearer k1' }).Code | Should -Be 415
    }

    It 'limits the request body also for chunked requests without Content-Length' {
        $ping = '{"jsonrpc":"2.0","id":1,"method":"ping"}'
        (Invoke-TestHttp -Path '/mcp' -Method POST -Body $ping -Chunked -Headers @{ Authorization = 'Bearer k1' }).Code | Should -Be 200
        InModuleScope MCPPosh { $script:McpMaxRequestBytes = 1KB }
        try {
            $large = '{"jsonrpc":"2.0","id":1,"method":"ping","params":{"pad":"' + ('x' * 4000) + '"}}'
            (Invoke-TestHttp -Path '/mcp' -Method POST -Body $large -Chunked -Headers @{ Authorization = 'Bearer k1' }).Code | Should -Be 413
            (Invoke-TestHttp -Path '/mcp' -Method POST -Body $large -Headers @{ Authorization = 'Bearer k1' }).Code | Should -Be 413
        }
        finally {
            InModuleScope MCPPosh { $script:McpMaxRequestBytes = 10MB }
        }
    }

    It 'closes the connection when the request body does not arrive in time' {
        InModuleScope MCPPosh { $script:McpRequestBodyTimeoutSeconds = 1 }
        $tcp = [System.Net.Sockets.TcpClient]::new('localhost', $script:Port)
        Register-McpTestDisposeAfter -InputObject $tcp -Seconds 15
        try {
            # Announce 1000 bytes, send only a few and keep the connection open (stalled or malicious client).
            $stream = $tcp.GetStream()
            $head = "POST /mcp HTTP/1.1`r`nHost: localhost:$($script:Port)`r`nAuthorization: Bearer k1`r`nContent-Type: application/json`r`nContent-Length: 1000`r`n`r`n{`"jsonrpc`""
            $bytes = [System.Text.Encoding]::ASCII.GetBytes($head)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush()

            $httpContext = $script:Listener.GetContext()
            $settings = @{ ApiKeys = @('k1'); AllowedOrigins = @(); IsLoopback = $true }
            $watch = [System.Diagnostics.Stopwatch]::StartNew()
            $status = InModuleScope MCPPosh -Parameters @{ Context = $script:Context; HttpContext = $httpContext; Settings = $settings } {
                param($Context, $HttpContext, $Settings)
                Invoke-McpHttpRequest -Context $Context -HttpContext $HttpContext -Settings $Settings
            }
            $watch.Elapsed.TotalSeconds | Should -BeLessThan 10
            $status | Should -Be 408

            # The client gets 408 (unless the platform resets the connection) and the server closes the connection:
            # reading ends with 0 bytes or a reset instead of timing out.
            $tcp.ReceiveTimeout = 5000
            $received = [System.Text.StringBuilder]::new()
            $chunk = [byte[]]::new(4096)
            $closed = $false
            try {
                while (($read = $stream.Read($chunk, 0, $chunk.Length)) -gt 0) {
                    $null = $received.Append([System.Text.Encoding]::ASCII.GetString($chunk, 0, $read))
                }
                $closed = $true
            }
            catch [System.IO.IOException] {
                $socketError = $_.Exception.InnerException
                $closed = -not ($socketError -is [System.Net.Sockets.SocketException] -and $socketError.SocketErrorCode -eq 'TimedOut')
            }
            $closed | Should -BeTrue
            if ($received.Length -gt 0) {
                $received.ToString() | Should -Match '^HTTP/1\.1 408 '
            }
        }
        finally {
            $tcp.Dispose()
            InModuleScope MCPPosh { $script:McpRequestBodyTimeoutSeconds = 30 }
        }
    }

    It 'checks origins, protocol versions and answers CORS preflight requests' {
        $ping = '{"jsonrpc":"2.0","id":1,"method":"ping"}'
        (Invoke-TestHttp -Path '/mcp' -Method POST -Body $ping -Headers @{ Authorization = 'Bearer k1'; Origin = 'https://evil.example.com' }).Code | Should -Be 403
        (Invoke-TestHttp -Path '/mcp' -Method POST -Body $ping -Headers @{ Authorization = 'Bearer k1'; 'MCP-Protocol-Version' = '1999-01-01' }).Code | Should -Be 400
        $preflight = Invoke-TestHttp -Path '/mcp' -Method OPTIONS -Headers @{ Origin = 'https://app.example.com' } -AllowedOrigins 'https://app.example.com'
        $preflight.Code | Should -Be 204
        $preflight.Headers.GetValues('Access-Control-Allow-Origin') | Should -Be 'https://app.example.com'
    }
}
