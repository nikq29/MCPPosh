BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../../TestHelpers/MCPPosh.TestHelpers.psm1') -Force
    $script:TestHome = Initialize-McpTestEnvironment
    $PSDefaultParameterValues['InModuleScope:ModuleName'] = 'MCPPosh'
    $script:Files = Join-Path $script:TestHome 'files'
    New-Item -ItemType Directory -Path $script:Files -Force | Out-Null
    $script:Html = @(
        '<html><head><title>VPN Help</title><style>body{}</style></head>'
        '<body><nav><a href="/">Home</a></nav>'
        '<main>'
        '  <h1>VPN Troubleshooting</h1>'
        '  <p>When the <b>VPN</b> connection   drops, <em>restart</em> the service &amp; check <code>vpnagent</code>:</p>'
        '  <pre><code class="language-powershell">Restart-Service vpnagent'
        'Get-Service vpnagent</code></pre>'
        '  <ul><li>Step one</li><li>Step two</li></ul>'
        '  <table><tr><th>Code</th><th>Meaning</th></tr><tr><td>809</td><td>Port blocked</td></tr></table>'
        '  <p>See <a href="details.html">details</a>.</p>'
        '  <script>alert(1)</script>'
        '</main></body></html>'
    ) -join "`n"
}

AfterAll {
    $PSDefaultParameterValues.Remove('InModuleScope:ModuleName')
    Remove-McpTestEnvironment -Path $script:TestHome
}

Describe 'ConvertFrom-McpHtmlFile' {
    It 'converts a local HTML file' {
        InModuleScope MCPPosh -Parameters @{ Files = $script:Files; Html = $script:Html } {
            param($Files, $Html)
            $path = Join-Path $Files 'vpn.html'
            Set-Content -Path $path -Value $Html
            $result = ConvertFrom-McpHtmlFile -Path $path
            $result.Title | Should -Be 'VPN Help'
            $result.Content | Should -Match '# VPN Troubleshooting'
        }
    }
}
