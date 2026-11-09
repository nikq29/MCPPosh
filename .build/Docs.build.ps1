<#
    Custom Sampler build tasks for the documentation (loaded by build.ps1 from the .build folder).
#>
# Synopsis: Removes the ProgressAction common parameter that platyPS 0.14 lists as a regular parameter on PowerShell 7.4 and later.
task Remove_ProgressAction_From_Markdown_Help {
    $helpFolder = Join-Path -Path $BuildRoot -ChildPath 'docs'
    foreach ($file in (Get-ChildItem -Path $helpFolder -Filter '*.md' -File -Recurse)) {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        $updated = $content -replace ' \[-ProgressAction <ActionPreference>\]', ''
        $updated = [regex]::Replace($updated, '(?ms)^### -ProgressAction\r?\n.*?(?=^### |^## )', '')
        if ($updated -cne $content) {
            Set-Content -LiteralPath $file.FullName -Value $updated -NoNewline -Encoding utf8
            Write-Build DarkGray "  Removed ProgressAction from $($file.Name)"
        }
    }
}
