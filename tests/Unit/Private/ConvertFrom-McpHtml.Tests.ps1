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

Describe 'ConvertFrom-McpHtml' {
    BeforeAll {
        $script:Converted = InModuleScope MCPPosh -Parameters @{ Html = $script:Html } {
            param($Html) ConvertFrom-McpHtml -Html $Html -BaseUrl 'https://docs.example.com/vpn/index.html'
        }
    }

    It 'extracts the title' {
        $script:Converted.Title | Should -Be 'VPN Help'
    }

    It 'converts headings, emphasis, inline code and entities' {
        $script:Converted.Content | Should -Match '(?m)^# VPN Troubleshooting$'
        $script:Converted.Content | Should -Match '\*\*VPN\*\* connection drops, \*restart\* the service & check `vpnagent`:'
    }

    It 'keeps preformatted code with its language' {
        $script:Converted.Content | Should -Match '(?s)```powershell\nRestart-Service vpnagent\nGet-Service vpnagent\n```'
    }

    It 'converts lists and tables' {
        $script:Converted.Content | Should -Match '(?m)^- Step one\n- Step two$'
        $script:Converted.Content | Should -Match '(?m)^\| 809 \| Port blocked \|$'
    }

    It 'resolves relative links and drops scripts, styles and navigation' {
        $script:Converted.Content | Should -Match '\[details\]\(https://docs\.example\.com/vpn/details\.html\)'
        $script:Converted.Content | Should -Not -Match 'alert|body\{\}|Home'
    }

    It 'adds the title as heading when the page has no h1' {
        InModuleScope MCPPosh {
            (ConvertFrom-McpHtml -Html '<html><head><title>Only Title</title></head><body><p>Body</p></body></html>').Content | Should -Match '^# Only Title'
        }
    }
}
