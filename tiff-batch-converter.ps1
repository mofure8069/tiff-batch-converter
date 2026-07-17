Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Image Batch Converter"
$form.Size = New-Object System.Drawing.Size(760,665)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = $form.Size

$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = "Root folder:"
$lblFolder.Location = New-Object System.Drawing.Point(10,15)
$lblFolder.AutoSize = $true
$form.Controls.Add($lblFolder)

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Location = New-Object System.Drawing.Point(90,12)
$txtFolder.Size = New-Object System.Drawing.Size(530,20)
$form.Controls.Add($txtFolder)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(630,10)
$btnBrowse.Size = New-Object System.Drawing.Size(100,24)
$form.Controls.Add($btnBrowse)

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "Scan for image folders"
$btnScan.Location = New-Object System.Drawing.Point(10,45)
$btnScan.Size = New-Object System.Drawing.Size(160,26)
$form.Controls.Add($btnScan)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text = "Uncheck any folder you don't want touched, or drag files/folders straight into the list below. Already-converted files are skipped (safe to re-run after Stop)."
$lblHint.Location = New-Object System.Drawing.Point(180,50)
$lblHint.Size = New-Object System.Drawing.Size(560,20)
$form.Controls.Add($lblHint)

$lblScanFormats = New-Object System.Windows.Forms.Label
$lblScanFormats.Text = "Scan for:"
$lblScanFormats.Location = New-Object System.Drawing.Point(10,80)
$lblScanFormats.AutoSize = $true
$form.Controls.Add($lblScanFormats)

$scanFormatDefs = @(
    @{ Name = "JPEG"; Pattern = "jpe?g" },
    @{ Name = "PNG";  Pattern = "png" },
    @{ Name = "GIF";  Pattern = "gif" },
    @{ Name = "BMP";  Pattern = "bmp" },
    @{ Name = "TIFF"; Pattern = "tiff?" },
    @{ Name = "WebP"; Pattern = "webp" }
)
$script:scanFormatChecks = @{}
$sfx = 80
foreach ($sf in $scanFormatDefs) {
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $sf.Name
    $chk.Checked = $false
    $chk.Location = New-Object System.Drawing.Point($sfx,78)
    $chk.AutoSize = $true
    $form.Controls.Add($chk)
    $script:scanFormatChecks[$sf.Pattern] = $chk
    $sfx += 65
}

$clb = New-Object System.Windows.Forms.ListView
$clb.Location = New-Object System.Drawing.Point(10,110)
$clb.Size = New-Object System.Drawing.Size(720,170)
$clb.View = [System.Windows.Forms.View]::Details
$clb.HeaderStyle = [System.Windows.Forms.ColumnHeaderStyle]::None
$clb.CheckBoxes = $true
$clb.FullRowSelect = $true
$clb.MultiSelect = $true
$clb.HideSelection = $false
$clb.AllowDrop = $true
[void]$clb.Columns.Add("Folder", 690)
$form.Controls.Add($clb)
$form.AllowDrop = $true

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "Delete Selected"
$btnDelete.Location = New-Object System.Drawing.Point(10,285)
$btnDelete.Size = New-Object System.Drawing.Size(120,24)
$form.Controls.Add($btnDelete)

$lblDeleteHint = New-Object System.Windows.Forms.Label
$lblDeleteHint.Text = "(click a row to toggle its selection, or Ctrl+A for all, then Delete Selected)"
$lblDeleteHint.Location = New-Object System.Drawing.Point(140,289)
$lblDeleteHint.AutoSize = $true
$form.Controls.Add($lblDeleteHint)

function Remove-SelectedFolderEntries {
    if ($script:running) { return }
    $selected = @($clb.SelectedIndices)
    if ($selected.Count -eq 0) { return }
    $selectedSet = [System.Collections.Generic.HashSet[int]]::new([int[]]$selected)
    $newData = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $script:folderData.Count; $i++) {
        if (-not $selectedSet.Contains($i)) { $newData.Add($script:folderData[$i]) }
    }
    $script:folderData = $newData.ToArray()
    foreach ($idx in ($selected | Sort-Object -Descending)) {
        $clb.Items.RemoveAt($idx)
    }
    $lblStatus.Text = "Removed $($selected.Count) entr$(if ($selected.Count -eq 1) {'y'} else {'ies'}) from the list."
    Add-Log $lblStatus.Text
    $btnStart.Enabled = ($clb.Items.Count -gt 0)
}

$btnDelete.Add_Click({ Remove-SelectedFolderEntries })

$clb.Add_KeyDown({
    param($s, $e)
    if ($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::A) {
        foreach ($item in $clb.Items) { $item.Selected = $true }
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    } elseif ($e.KeyCode -eq [System.Windows.Forms.Keys]::Delete) {
        Remove-SelectedFolderEntries
        $e.Handled = $true
        $e.SuppressKeyPress = $true
    }
})

$script:dropImgExtRegex = '^\.(jpe?g|png|gif|bmp|tiff?|webp)$'

function Add-DroppedPaths([string[]]$paths) {
    if ($script:running) { return }
    $collected = New-Object System.Collections.Generic.List[System.IO.FileInfo]
    foreach ($p in $paths) {
        if (Test-Path -LiteralPath $p -PathType Container) {
            $found = Get-ChildItem -LiteralPath $p -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.Extension -match $script:dropImgExtRegex -and
                    $_.FullName -notmatch '\\_TIF_BACKUP\\' -and
                    $_.FullName -notmatch '\\\w+_output\\' -and
                    $_.FullName -notmatch '\\screenshots\\'
                }
            foreach ($f in $found) { $collected.Add($f) }
        } elseif (Test-Path -LiteralPath $p -PathType Leaf) {
            $fi = Get-Item -LiteralPath $p
            if ($fi.Extension -match $script:dropImgExtRegex) { $collected.Add($fi) }
        }
    }

    if ($collected.Count -eq 0) {
        $lblStatus.Text = "Nothing supported in what you dropped (JPEG/PNG/GIF/BMP/TIFF/WebP only)."
        return
    }

    $newGroups = $collected | Group-Object DirectoryName
    $addedFiles = 0
    $addedFolders = 0
    foreach ($g in $newGroups) {
        $existingIdx = -1
        for ($i = 0; $i -lt $script:folderData.Count; $i++) {
            if ($script:folderData[$i].Path -eq $g.Name) { $existingIdx = $i; break }
        }
        if ($existingIdx -ge 0) {
            $existingFiles = @($script:folderData[$existingIdx].Files)
            $existingNames = $existingFiles | ForEach-Object { $_.FullName }
            $newOnes = @($g.Group | Where-Object { $existingNames -notcontains $_.FullName })
            if ($newOnes.Count -gt 0) {
                $mergedFiles = $existingFiles + $newOnes
                $script:folderData[$existingIdx].Files = $mergedFiles
                $addedFiles += $newOnes.Count
                $sizeMB = [math]::Round(($mergedFiles | Measure-Object Length -Sum).Sum / 1MB, 1)
                $clb.Items[$existingIdx].Text = "[$($mergedFiles.Count) files, $sizeMB MB]  $($g.Name)"
            }
        } else {
            $sizeMB = [math]::Round(($g.Group | Measure-Object Length -Sum).Sum / 1MB, 1)
            $label = "[$($g.Count) files, $sizeMB MB]  $($g.Name)"
            $newItem = New-Object System.Windows.Forms.ListViewItem($label)
            $newItem.Checked = $true
            $clb.Items.Add($newItem) | Out-Null
            $script:folderData += [PSCustomObject]@{ Path = $g.Name; Files = @($g.Group) }
            $addedFiles += $g.Count
            $addedFolders++
        }
    }
    $lblStatus.Text = "Dropped: added $addedFiles file(s), $addedFolders new folder(s) to the list."
    Add-Log $lblStatus.Text
    $btnStart.Enabled = ($clb.Items.Count -gt 0)
}

$dragEnterHandler = {
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    } else {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::None
    }
}
$dragDropHandler = {
    param($s, $e)
    $paths = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
    Add-DroppedPaths -paths $paths
}
$clb.Add_DragEnter($dragEnterHandler)
$clb.Add_DragDrop($dragDropHandler)
$form.Add_DragEnter($dragEnterHandler)
$form.Add_DragDrop($dragDropHandler)

$lblFormat = New-Object System.Windows.Forms.Label
$lblFormat.Text = "Output format:"
$lblFormat.Location = New-Object System.Drawing.Point(10,320)
$lblFormat.AutoSize = $true
$form.Controls.Add($lblFormat)

$cmbFormat = New-Object System.Windows.Forms.ComboBox
$cmbFormat.DropDownStyle = "DropDownList"
$cmbFormat.Items.AddRange(@("JPEG","WebP","PNG"))
$cmbFormat.SelectedIndex = 0
$cmbFormat.Location = New-Object System.Drawing.Point(110,317)
$cmbFormat.Size = New-Object System.Drawing.Size(80,22)
$form.Controls.Add($cmbFormat)

$lblQuality = New-Object System.Windows.Forms.Label
$lblQuality.Text = "Quality (1-100):"
$lblQuality.Location = New-Object System.Drawing.Point(210,320)
$lblQuality.AutoSize = $true
$form.Controls.Add($lblQuality)

$numQuality = New-Object System.Windows.Forms.NumericUpDown
$numQuality.Minimum = 1
$numQuality.Maximum = 100
$numQuality.Value = 90
$numQuality.Location = New-Object System.Drawing.Point(330,318)
$numQuality.Size = New-Object System.Drawing.Size(60,20)
$form.Controls.Add($numQuality)

$cmbFormat.Add_SelectedIndexChanged({
    $isPng = ($cmbFormat.SelectedItem -eq "PNG")
    $numQuality.Enabled = -not $isPng
    $lblQuality.Enabled = -not $isPng
    $lblQuality.Text = if ($isPng) { "(PNG is lossless, no quality setting)" } else { "Quality (1-100):" }
})

$lblParallel = New-Object System.Windows.Forms.Label
$lblParallel.Text = "Parallel jobs:"
$lblParallel.Location = New-Object System.Drawing.Point(10,354)
$lblParallel.AutoSize = $true
$form.Controls.Add($lblParallel)

$numParallel = New-Object System.Windows.Forms.NumericUpDown
$numParallel.Minimum = 1
$numParallel.Maximum = 32
$numParallel.Value = [Math]::Max(1, [Environment]::ProcessorCount)
$numParallel.Location = New-Object System.Drawing.Point(110,351)
$numParallel.Size = New-Object System.Drawing.Size(60,20)
$form.Controls.Add($numParallel)

$lblParallelHint = New-Object System.Windows.Forms.Label
$lblParallelHint.Text = "(runs this many conversions at once - big speedup on multi-core CPUs)"
$lblParallelHint.Location = New-Object System.Drawing.Point(180,354)
$lblParallelHint.AutoSize = $true
$form.Controls.Add($lblParallelHint)

$chkStrip = New-Object System.Windows.Forms.CheckBox
$chkStrip.Text = "Strip metadata (faster + smaller, drops color profile/EXIF)"
$chkStrip.Checked = $false
$chkStrip.Location = New-Object System.Drawing.Point(10,377)
$chkStrip.AutoSize = $true
$form.Controls.Add($chkStrip)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start"
$btnStart.Location = New-Object System.Drawing.Point(10,405)
$btnStart.Size = New-Object System.Drawing.Size(120,32)
$btnStart.Enabled = $false
$form.Controls.Add($btnStart)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "Stop"
$btnStop.Location = New-Object System.Drawing.Point(140,405)
$btnStop.Size = New-Object System.Drawing.Size(120,32)
$btnStop.Enabled = $false
$form.Controls.Add($btnStop)

$progressOverall = New-Object System.Windows.Forms.ProgressBar
$progressOverall.Location = New-Object System.Drawing.Point(10,445)
$progressOverall.Size = New-Object System.Drawing.Size(720,25)
$form.Controls.Add($progressOverall)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(10,475)
$lblStatus.Size = New-Object System.Drawing.Size(720,20)
$lblStatus.Text = "Idle. Pick a root folder and click Scan."
$form.Controls.Add($lblStatus)

$txtLog = New-Object System.Windows.Forms.TextBox
$txtLog.Multiline = $true
$txtLog.ScrollBars = "Vertical"
$txtLog.Location = New-Object System.Drawing.Point(10,500)
$txtLog.Size = New-Object System.Drawing.Size(720,130)
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($txtLog)

$script:cancelRequested = $false
$script:folderData = @()
$script:running = $false

function Add-Log([string]$msg) {
    $txtLog.AppendText("$(Get-Date -Format 'HH:mm:ss') $msg`r`n")
}

$btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    if (Test-Path $txtFolder.Text) { $fbd.SelectedPath = $txtFolder.Text }
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtFolder.Text = $fbd.SelectedPath
    }
})

$btnScan.Add_Click({
    $root = $txtFolder.Text
    if (-not (Test-Path $root)) {
        [System.Windows.Forms.MessageBox]::Show("Folder not found: $root") | Out-Null
        return
    }
    $clb.Items.Clear()
    $script:folderData = @()
    $btnStart.Enabled = $false
    $lblStatus.Text = "Scanning..."
    [System.Windows.Forms.Application]::DoEvents()

    $activePatterns = @($script:scanFormatChecks.Keys | Where-Object { $script:scanFormatChecks[$_].Checked })
    if ($activePatterns.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Check at least one format to scan for.") | Out-Null
        $lblStatus.Text = "Idle. Pick a root folder and click Scan."
        return
    }
    $extRegex = '^\.(' + ($activePatterns -join '|') + ')$'

    $files = Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -match $extRegex -and
            $_.FullName -notmatch '\\_TIF_BACKUP\\' -and
            $_.FullName -notmatch '\\\w+_output\\' -and
            $_.FullName -notmatch '\\screenshots\\'
        }
    $groups = $files | Group-Object DirectoryName

    foreach ($g in $groups) {
        $sizeMB = [math]::Round(($g.Group | Measure-Object Length -Sum).Sum / 1MB, 1)
        $relPath = $g.Name
        $label = "[$($g.Count) files, $sizeMB MB]  $relPath"
        $scanItem = New-Object System.Windows.Forms.ListViewItem($label)
        $scanItem.Checked = $true
        $clb.Items.Add($scanItem) | Out-Null
        $script:folderData += [PSCustomObject]@{ Path = $g.Name; Files = $g.Group }
    }
    $lblStatus.Text = "Found $($groups.Count) folder(s) with image files, $($files.Count) files total."
    Add-Log $lblStatus.Text
    $btnStart.Enabled = ($groups.Count -gt 0)
})

$btnStart.Add_Click({
    $checkedCount = @($clb.Items | Where-Object { $_.Checked }).Count
    if ($checkedCount -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No folders selected.") | Out-Null
        return
    }
    $script:cancelRequested = $false
    $script:running = $true
    $btnStart.Enabled = $false
    $btnStop.Enabled = $true
    $btnScan.Enabled = $false
    $btnBrowse.Enabled = $false
    $btnDelete.Enabled = $false

    $selectedIndices = 0..($clb.Items.Count - 1) | Where-Object { $clb.Items[$_].Checked }
    $selectedFolders = $selectedIndices | ForEach-Object { $script:folderData[$_] }

    $allFiles = @()
    foreach ($fd in $selectedFolders) { $allFiles += $fd.Files }
    $total = $allFiles.Count
    $progressOverall.Maximum = [math]::Max($total,1)
    $progressOverall.Value = 0
    $done = 0
    $errCount = 0
    $quality = $numQuality.Value
    $format = $cmbFormat.SelectedItem.ToString()
    $ext = switch ($format) { "WebP" { ".webp" } "JPEG" { ".jpg" } "PNG" { ".png" } }
    $outDirName = "$($format.ToLower())_output"
    $parallelJobs = [int]$numParallel.Value
    $stripMeta = $chkStrip.Checked

    foreach ($fd in $selectedFolders) {
        if ($script:cancelRequested) { break }
        $dir = $fd.Path
        $tifFiles = $fd.Files
        Add-Log "=== $dir ($($tifFiles.Count) files) ==="
        [System.Windows.Forms.Application]::DoEvents()

        $outDir = Join-Path $dir $outDirName
        if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }

        $queue = New-Object System.Collections.Generic.Queue[object]
        foreach ($f in $tifFiles) { $queue.Enqueue($f) }
        $inFlight = @()

        while (($queue.Count -gt 0 -or $inFlight.Count -gt 0) -and -not $script:cancelRequested) {
            while ($inFlight.Count -lt $parallelJobs -and $queue.Count -gt 0) {
                $f = $queue.Dequeue()
                $outFile = Join-Path $outDir ($f.BaseName + $ext)
                if (Test-Path $outFile) {
                    $done++
                    $progressOverall.Value = [math]::Min($done, $total)
                    continue
                }
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "magick"
                $argParts = New-Object System.Collections.Generic.List[string]
                $argParts.Add("`"$($f.FullName)`"")
                if ($stripMeta) { $argParts.Add("-strip") }
                if ($format -ne "PNG") { $argParts.Add("-quality"); $argParts.Add("$quality") }
                $argParts.Add("`"$outFile`"")
                $psi.Arguments = $argParts -join " "
                $psi.UseShellExecute = $false
                $psi.CreateNoWindow = $true
                $proc = [System.Diagnostics.Process]::Start($psi)
                $inFlight += [PSCustomObject]@{ Proc = $proc; File = $f; OutFile = $outFile }
            }

            $lblStatus.Text = "Converting: $done/$total done, $($inFlight.Count) in progress..."
            Start-Sleep -Milliseconds 80
            [System.Windows.Forms.Application]::DoEvents()

            $stillRunning = @()
            foreach ($job in $inFlight) {
                if ($job.Proc.HasExited) {
                    if (-not (Test-Path $job.OutFile) -or (Get-Item $job.OutFile).Length -eq 0) {
                        Add-Log "  ERROR converting: $($job.File.Name)"
                        $errCount++
                    }
                    $done++
                    $progressOverall.Value = [math]::Min($done, $total)
                } else {
                    $stillRunning += $job
                }
            }
            $inFlight = $stillRunning
        }

        if ($script:cancelRequested -and $inFlight.Count -gt 0) {
            foreach ($job in $inFlight) { try { $job.Proc.Kill() } catch {} }
        }
    }

    if ($script:cancelRequested) {
        $lblStatus.Text = "Stopped by user at $done/$total files."
    } else {
        $lblStatus.Text = "Done. $done/$total files processed, $errCount error(s)."
    }
    Add-Log $lblStatus.Text
    $script:running = $false
    $btnStart.Enabled = $true
    $btnStop.Enabled = $false
    $btnScan.Enabled = $true
    $btnBrowse.Enabled = $true
    $btnDelete.Enabled = $true
})

$btnStop.Add_Click({
    $script:cancelRequested = $true
    $lblStatus.Text = "Stopping (finishing current file)..."
})

$form.Add_FormClosing({
    param($s,$e)
    if ($script:running) {
        $script:cancelRequested = $true
    }
})

$form.Add_Shown({
    if (Test-Path "E:\6.相册\8.Painting") { $txtFolder.Text = "E:\6.相册\8.Painting" }
})

[void]$form.ShowDialog()
