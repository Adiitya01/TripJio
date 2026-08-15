# ============================================================
# Markdown to DOCX via HTML (reliable approach)
# ============================================================

$ErrorActionPreference = "Stop"
$projectDir = "C:\Users\pasar\OneDrive\Desktop\TripJio"

$files = @(
    "PLATFORM_READINESS_REPORT.md",
    "PLAY_STORE_LAUNCH_PLAN.md",
    "TERMS_AND_CONDITIONS.md"
)

function Convert-MdToHtml {
    param([string]$md)

    $css = @"
<style>
body { font-family: 'Calibri', Arial, sans-serif; font-size: 11pt; color: #222; max-width: 7.5in; }
h1 { color: #003F7D; font-size: 22pt; border-bottom: 2px solid #003F7D; padding-bottom: 6px; margin-top: 24px; }
h2 { color: #003F7D; font-size: 16pt; margin-top: 20px; }
h3 { color: #003F7D; font-size: 13pt; margin-top: 16px; }
h4 { color: #444; font-size: 12pt; }
table { border-collapse: collapse; width: 100%; margin: 12px 0; }
th { background: #003F7D; color: white; padding: 8px; text-align: left; border: 1px solid #003F7D; font-weight: bold; font-size: 10pt; }
td { padding: 8px; border: 1px solid #ccc; vertical-align: top; font-size: 10pt; }
tr:nth-child(even) td { background: #f5f7fa; }
ul, ol { margin: 6px 0 12px 24px; }
li { margin-bottom: 4px; }
code { background: #f0f0f0; padding: 2px 6px; border-radius: 3px; font-family: 'Consolas', monospace; font-size: 10pt; }
pre { background: #f0f0f0; padding: 10px; border-left: 3px solid #003F7D; font-family: 'Consolas', monospace; font-size: 9pt; overflow-x: auto; }
hr { border: none; border-top: 1px solid #ccc; margin: 18px 0; }
blockquote { border-left: 4px solid #003F7D; padding-left: 12px; color: #555; margin: 12px 0; font-style: italic; }
strong { color: #003F7D; }
</style>
"@

    $lines = $md -split "`r?`n"
    $html = New-Object System.Collections.Generic.List[string]
    $inTable = $false
    $inList = $false
    $listType = ""
    $inCode = $false
    $tableRows = @()

    function Format-Inline {
        param([string]$text)
        # Escape HTML
        $text = $text -replace '&', '&amp;'
        $text = $text -replace '<', '&lt;'
        $text = $text -replace '>', '&gt;'
        # Bold
        $text = $text -replace '\*\*(.+?)\*\*', '<strong>$1</strong>'
        # Italic (be careful — only single asterisks)
        $text = $text -replace '(?<![\*])\*([^\*\n]+?)\*(?![\*])', '<em>$1</em>'
        # Inline code
        $text = $text -replace '`([^`]+?)`', '<code>$1</code>'
        # Links
        $text = $text -replace '\[(.+?)\]\((.+?)\)', '<a href="$2">$1</a>'
        return $text
    }

    foreach ($line in $lines) {
        # Code fence
        if ($line -match '^```') {
            if ($inCode) {
                $html.Add("</pre>")
                $inCode = $false
            } else {
                $html.Add("<pre>")
                $inCode = $true
            }
            continue
        }
        if ($inCode) {
            $escaped = $line -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;'
            $html.Add($escaped)
            continue
        }

        # Tables
        if ($line -match '^\|') {
            if ($line -match '^\|\s*[-:]+\s*\|') {
                # separator line — skip, but mark header is done
                continue
            }
            if (-not $inTable) {
                $html.Add('<table>')
                $inTable = $true
                $firstRow = $true
            }
            $cells = $line -split '\|' | ForEach-Object { $_.Trim() }
            $cells = $cells[1..($cells.Count - 2)]
            if ($firstRow) {
                $row = "<tr>" + (($cells | ForEach-Object { "<th>" + (Format-Inline $_) + "</th>" }) -join "") + "</tr>"
                $firstRow = $false
            } else {
                $row = "<tr>" + (($cells | ForEach-Object { "<td>" + (Format-Inline $_) + "</td>" }) -join "") + "</tr>"
            }
            $html.Add($row)
            continue
        } elseif ($inTable) {
            $html.Add('</table>')
            $inTable = $false
            $firstRow = $false
        }

        # Lists
        if ($line -match '^\s*[-*]\s+(.+)$') {
            $itemText = $matches[1]
            if (-not $inList -or $listType -ne "ul") {
                if ($inList) { $html.Add("</$listType>") }
                $html.Add("<ul>")
                $inList = $true
                $listType = "ul"
            }
            $html.Add("<li>" + (Format-Inline $itemText) + "</li>")
            continue
        }
        if ($line -match '^\s*\d+\.\s+(.+)$') {
            $itemText = $matches[1]
            if (-not $inList -or $listType -ne "ol") {
                if ($inList) { $html.Add("</$listType>") }
                $html.Add("<ol>")
                $inList = $true
                $listType = "ol"
            }
            $html.Add("<li>" + (Format-Inline $itemText) + "</li>")
            continue
        } elseif ($inList -and $line -notmatch '^\s*$' -and $line -notmatch '^\s*[-*]\s+' -and $line -notmatch '^\s*\d+\.\s+') {
            $html.Add("</$listType>")
            $inList = $false
        }

        # Headings
        if ($line -match '^####\s+(.+)$') { $html.Add("<h4>" + (Format-Inline $matches[1]) + "</h4>"); continue }
        if ($line -match '^###\s+(.+)$')  { $html.Add("<h3>" + (Format-Inline $matches[1]) + "</h3>"); continue }
        if ($line -match '^##\s+(.+)$')   { $html.Add("<h2>" + (Format-Inline $matches[1]) + "</h2>"); continue }
        if ($line -match '^#\s+(.+)$')    { $html.Add("<h1>" + (Format-Inline $matches[1]) + "</h1>"); continue }

        # Horizontal rule
        if ($line -match '^-{3,}\s*$') { $html.Add("<hr>"); continue }

        # Blockquote
        if ($line -match '^>\s+(.+)$') {
            $html.Add("<blockquote>" + (Format-Inline $matches[1]) + "</blockquote>")
            continue
        }

        # Blank line
        if ($line -match '^\s*$') {
            if ($inList) { $html.Add("</$listType>"); $inList = $false }
            $html.Add("<p>&nbsp;</p>")
            continue
        }

        # Regular paragraph
        $html.Add("<p>" + (Format-Inline $line) + "</p>")
    }

    # Close any open lists/tables
    if ($inList) { $html.Add("</$listType>") }
    if ($inTable) { $html.Add('</table>') }

    $body = $html -join "`n"
    return "<!DOCTYPE html><html><head><meta charset='UTF-8'>$css</head><body>$body</body></html>"
}

Write-Host "Starting Word..." -ForegroundColor Cyan
$word = New-Object -ComObject Word.Application
$word.Visible = $false
$word.DisplayAlerts = 0

try {
    foreach ($f in $files) {
        $mdPath = Join-Path $projectDir $f
        if (-not (Test-Path $mdPath)) {
            Write-Host "  Skipped (not found): $f" -ForegroundColor Yellow
            continue
        }
        Write-Host ""
        Write-Host "Converting $f..." -ForegroundColor Yellow

        # Convert MD to HTML
        $md = Get-Content -Path $mdPath -Raw -Encoding UTF8
        $html = Convert-MdToHtml -md $md

        # Save HTML temp
        $htmlPath = $mdPath -replace '\.md$', '.tmp.html'
        [System.IO.File]::WriteAllText($htmlPath, $html, [System.Text.Encoding]::UTF8)

        # Open HTML in Word
        $doc = $word.Documents.Open($htmlPath, $false, $true)

        # Save as DOCX
        $docxPath = $mdPath -replace '\.md$', '.docx'
        $doc.SaveAs2($docxPath, 16)  # 16 = wdFormatDocumentDefault (.docx)
        $doc.Close($false)

        # Clean up temp HTML
        Remove-Item $htmlPath -Force

        $size = [math]::Round((Get-Item $docxPath).Length / 1KB, 1)
        Write-Host "  Saved: $(Split-Path $docxPath -Leaf) ($size KB)" -ForegroundColor Green
    }
} finally {
    $word.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    [GC]::Collect()
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  Conversion complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
