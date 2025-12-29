#!/usr/bin/env pwsh
<#!
.SYNOPSIS
  Rewrite Markdown links ending with .md to extensionless paths for Hugo.

.DESCRIPTION
  Keeps repository Markdown readable on GitHub (with .md links), but allows
  CI/local builds to transform links like:

    [Diagrams](./diagrams.md)

  into:

    [Diagrams](./diagrams/)

  so that Hugo-generated pages use directory-style URLs.

.EXAMPLE
  pwsh ./scripts/fix-hugo-links.ps1              # defaults to ./docs
  pwsh ./scripts/fix-hugo-links.ps1 -Root docs/en
#>

param(
    [string]$Root = "docs"
)

if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    Write-Error "Directory '$Root' not found."
    exit 1
}

$opts = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor `
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase

# Pattern 1: [Text](./path.md) -> [Text](./path/)
$pattern1 = '\]\(\./([^)\r\n]*?)\.md\)'
# Pattern 2: [Text](path.md) -> [Text](path/), where path does not start
# with http(s), #, or /
$pattern2 = '\]\((?!(https?://|#|/))([^)\r\n]*?)\.md\)'

Get-ChildItem -Path $Root -Filter '*.md' -Recurse | ForEach-Object {
    $filePath = $_.FullName
    $text = Get-Content -LiteralPath $filePath -Raw

    $text = [System.Text.RegularExpressions.Regex]::Replace(
        $text,
        $pattern1,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            # $m.Groups[1] is the relative path without .md
            return "](./" + $m.Groups[1].Value + "/)"
        },
        $opts
    )

    $text = [System.Text.RegularExpressions.Regex]::Replace(
        $text,
        $pattern2,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            # $m.Groups[2] is the relative path without .md
            return "](" + $m.Groups[2].Value + "/)"
        },
        $opts
    )

    Set-Content -LiteralPath $filePath -Value $text
}

Write-Host "Rewrote Markdown links under '$Root' for Hugo."