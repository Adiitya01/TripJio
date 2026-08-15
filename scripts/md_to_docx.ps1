# ============================================================
# Markdown to Word (.docx) Converter
# Uses Microsoft Word COM automation
# ============================================================
# Usage: powershell -ExecutionPolicy Bypass -File md_to_docx.ps1
# ============================================================

param(
    [string[]]$Files = @(
        "PLATFORM_READINESS_REPORT.md",
        "PLAY_STORE_LAUNCH_PLAN.md",
        "TERMS_AND_CONDITIONS.md"
    )
)

$ErrorActionPreference = "Stop"
$projectDir = "C:\Users\pasar\OneDrive\Desktop\TripJio"

Write-Host " Starting Word..." -ForegroundColor Cyan
$word = New-Object -ComObject Word.Application
$word.Visible = $false

# Word constants
$wdFormatDocumentDefault = 16    # .docx
$wdStyleHeading1 = -2
$wdStyleHeading2 = -3
$wdStyleHeading3 = -4
$wdStyleNormal = -1
$wdAlignParagraphLeft = 0
$wdAlignParagraphCenter = 1
$wdLineStyleSingle = 1
$wdAutoFitContent = 2
$wdAutoFitWindow = 1

function Convert-File {
    param([string]$mdPath, [string]$docxPath, [string]$title)

    Write-Host ""
    Write-Host " Converting $title..." -ForegroundColor Yellow

    $doc = $word.Documents.Add()
    $selection = $word.Selection

    # ─── Default font: Arial 11 ───
    $selection.Font.Name = "Calibri"
    $selection.Font.Size = 11

    $lines = Get-Content -Path $mdPath -Encoding UTF8
    $i = 0
    $inCodeBlock = $false

    while ($i -lt $lines.Count) {
        $line = $lines[$i]

        # ─── Skip code fences ───
        if ($line -match '^```') {
            $inCodeBlock = -not $inCodeBlock
            $i++
            continue
        }
        if ($inCodeBlock) {
            $selection.Font.Name = "Consolas"
            $selection.Font.Size = 9
            $selection.TypeText($line)
            $selection.TypeParagraph()
            $selection.Font.Name = "Calibri"
            $selection.Font.Size = 11
            $i++
            continue
        }

        # ─── Horizontal rule ───
        if ($line -match '^---+\s*$') {
            $selection.ParagraphFormat.Borders.Item(-3).LineStyle = $wdLineStyleSingle
            $selection.TypeParagraph()
            $selection.ParagraphFormat.Borders.Item(-3).LineStyle = 0
            $i++
            continue
        }

        # ─── Blank line ───
        if ($line -match '^\s*$') {
            $selection.TypeParagraph()
            $i++
            continue
        }

        # ─── Headings ───
        if ($line -match '^# (.+)$') {
            $selection.Style = $doc.Styles.Item("Heading 1")
            $selection.Font.Color = 4209970  # dark navy
            $selection.TypeText($matches[1])
            $selection.TypeParagraph()
            $selection.Style = $doc.Styles.Item("Normal")
            $selection.Font.Name = "Calibri"
            $selection.Font.Size = 11
            $selection.Font.Color = 0
            $i++
            continue
        }
        if ($line -match '^## (.+)$') {
            $selection.Style = $doc.Styles.Item("Heading 2")
            $selection.Font.Color = 4209970
            $selection.TypeText($matches[1])
            $selection.TypeParagraph()
            $selection.Style = $doc.Styles.Item("Normal")
            $selection.Font.Name = "Calibri"
            $selection.Font.Size = 11
            $selection.Font.Color = 0
            $i++
            continue
        }
        if ($line -match '^### (.+)$') {
            $selection.Style = $doc.Styles.Item("Heading 3")
            $selection.Font.Color = 4209970
            $selection.TypeText($matches[1])
            $selection.TypeParagraph()
            $selection.Style = $doc.Styles.Item("Normal")
            $selection.Font.Name = "Calibri"
            $selection.Font.Size = 11
            $selection.Font.Color = 0
            $i++
            continue
        }
        if ($line -match '^#### (.+)$') {
            $selection.Style = $doc.Styles.Item("Heading 4")
            $selection.TypeText($matches[1])
            $selection.TypeParagraph()
            $selection.Style = $doc.Styles.Item("Normal")
            $i++
            continue
        }

        # ─── Tables ───
        if ($line -match '^\|') {
            # Collect rows
            $rows = @()
            while ($i -lt $lines.Count -and $lines[$i] -match '^\|') {
                $rows += $lines[$i]
                $i++
            }
            if ($rows.Count -ge 2) {
                # Filter out separator row (---|---)
                $dataRows = @()
                foreach ($r in $rows) {
                    if ($r -notmatch '^\|\s*[-:]+') {
                        $dataRows += $r
                    }
                }
                if ($dataRows.Count -gt 0) {
                    # Parse cells
                    $tableData = @()
                    foreach ($r in $dataRows) {
                        $cells = $r -split '\|' | ForEach-Object { $_.Trim() }
                        # Remove first and last empty (from leading/trailing |)
                        $cells = $cells[1..($cells.Count - 2)]
                        $tableData += , $cells
                    }
                    $rowCount = $tableData.Count
                    $colCount = $tableData[0].Count

                    # Insert table
                    $range = $selection.Range
                    $table = $doc.Tables.Add($range, $rowCount, $colCount)
                    $table.Borders.Enable = $true
                    $table.AutoFitBehavior($wdAutoFitWindow)

                    for ($r = 0; $r -lt $rowCount; $r++) {
                        for ($c = 0; $c -lt $colCount; $c++) {
                            $cellText = if ($c -lt $tableData[$r].Count) {
                                $tableData[$r][$c] -replace '\*\*(.+?)\*\*', '$1'
                            } else { "" }
                            $cell = $table.Cell($r + 1, $c + 1)
                            $cell.Range.Text = $cellText
                            if ($r -eq 0) {
                                $cell.Range.Font.Bold = $true
                                $cell.Range.Shading.BackgroundPatternColor = 14671839
                            }
                            $cell.Range.Font.Size = 10
                        }
                    }

                    # Move past the table
                    $selection.EndKey(6) | Out-Null   # 6 = wdStory
                    $selection.TypeParagraph()
                }
            }
            continue
        }

        # ─── Bullet list ───
        if ($line -match '^\s*[-*]\s+(.+)$') {
            $itemText = $matches[1]
            $selection.Range.ListFormat.ApplyBulletDefault()
            Write-FormattedText $selection $itemText
            $selection.TypeParagraph()
            # Continue collecting bullets
            $i++
            while ($i -lt $lines.Count -and $lines[$i] -match '^\s*[-*]\s+(.+)$') {
                Write-FormattedText $selection $matches[1]
                $selection.TypeParagraph()
                $i++
            }
            $selection.Range.ListFormat.RemoveNumbers()
            continue
        }

        # ─── Numbered list ───
        if ($line -match '^\s*\d+\.\s+(.+)$') {
            $itemText = $matches[1]
            $selection.Range.ListFormat.ApplyNumberDefault()
            Write-FormattedText $selection $itemText
            $selection.TypeParagraph()
            $i++
            while ($i -lt $lines.Count -and $lines[$i] -match '^\s*\d+\.\s+(.+)$') {
                Write-FormattedText $selection $matches[1]
                $selection.TypeParagraph()
                $i++
            }
            $selection.Range.ListFormat.RemoveNumbers()
            continue
        }

        # ─── Bold quote (> text) ───
        if ($line -match '^>\s*(.+)$') {
            $selection.Font.Italic = $true
            $selection.Font.Color = 6710886
            $selection.TypeText($matches[1])
            $selection.TypeParagraph()
            $selection.Font.Italic = $false
            $selection.Font.Color = 0
            $i++
            continue
        }

        # ─── Regular paragraph (handle **bold**) ───
        Write-FormattedText $selection $line
        $selection.TypeParagraph()
        $i++
    }

    # ─── Save ───
    $absolutePath = Join-Path $projectDir $docxPath
    $doc.SaveAs2($absolutePath, $wdFormatDocumentDefault)
    $doc.Close()

    Write-Host "   Saved: $docxPath" -ForegroundColor Green
}

function Write-FormattedText {
    param($sel, [string]$text)
    # Split on **bold** markers
    $parts = [regex]::Split($text, '(\*\*[^*]+\*\*)')
    foreach ($p in $parts) {
        if ($p -match '^\*\*(.+)\*\*$') {
            $sel.Font.Bold = $true
            $sel.TypeText($matches[1])
            $sel.Font.Bold = $false
        } else {
            $sel.TypeText($p)
        }
    }
}

try {
    foreach ($f in $Files) {
        $mdPath = Join-Path $projectDir $f
        $docxName = [System.IO.Path]::ChangeExtension($f, ".docx")
        if (Test-Path $mdPath) {
            Convert-File -mdPath $mdPath -docxPath $docxName -title $f
        } else {
            Write-Host "   Skipped (not found): $f" -ForegroundColor Yellow
        }
    }
}
finally {
    $word.Quit()
    [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) | Out-Null
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  All conversions complete!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Files saved to: $projectDir" -ForegroundColor White
Write-Host ""
