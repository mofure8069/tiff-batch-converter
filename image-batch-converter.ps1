Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Image Batch Converter"
$form.Size = New-Object System.Drawing.Size(760,784)
$form.StartPosition = "CenterScreen"
$form.MinimumSize = $form.Size

$lblIntro = New-Object System.Windows.Forms.Label
$lblIntro.Text = "Follow steps 1-4 below. Step 1: pick a root folder to scan, or just drag files/folders into the list (step 3) instead."
$lblIntro.Location = New-Object System.Drawing.Point(10,15)
$lblIntro.AutoSize = $true
$form.Controls.Add($lblIntro)

$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Text = "1) Root folder:"
$lblFolder.Location = New-Object System.Drawing.Point(10,38)
$lblFolder.AutoSize = $true
$form.Controls.Add($lblFolder)

$txtFolder = New-Object System.Windows.Forms.TextBox
$txtFolder.Location = New-Object System.Drawing.Point(90,35)
$txtFolder.Size = New-Object System.Drawing.Size(530,20)
$form.Controls.Add($txtFolder)

$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(630,33)
$btnBrowse.Size = New-Object System.Drawing.Size(100,24)
$form.Controls.Add($btnBrowse)

$btnScan = New-Object System.Windows.Forms.Button
$btnScan.Text = "2) Scan for image folders"
$btnScan.Location = New-Object System.Drawing.Point(10,68)
$btnScan.Size = New-Object System.Drawing.Size(160,26)
$form.Controls.Add($btnScan)

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text = "Uncheck folders to skip, or drag files/folders in directly."
$lblHint.Location = New-Object System.Drawing.Point(180,73)
$lblHint.Size = New-Object System.Drawing.Size(560,20)
$form.Controls.Add($lblHint)

$lblScanFormats = New-Object System.Windows.Forms.Label
$lblScanFormats.Text = "Scan for:"
$lblScanFormats.Location = New-Object System.Drawing.Point(10,103)
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
$chkAllFormats = New-Object System.Windows.Forms.CheckBox
$chkAllFormats.Text = "All"
$chkAllFormats.Checked = $false
$chkAllFormats.Location = New-Object System.Drawing.Point(80,101)
$chkAllFormats.AutoSize = $true
$form.Controls.Add($chkAllFormats)

$script:scanFormatChecks = @{}
$sfx = 145
foreach ($sf in $scanFormatDefs) {
    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = $sf.Name
    $chk.Checked = $false
    $chk.Location = New-Object System.Drawing.Point($sfx,101)
    $chk.AutoSize = $true
    $form.Controls.Add($chk)
    $script:scanFormatChecks[$sf.Pattern] = $chk
    $sfx += 65
}

$lblMinSize = New-Object System.Windows.Forms.Label
$lblMinSize.Text = "Min size (MB):"
$lblMinSize.Location = New-Object System.Drawing.Point(545,103)
$lblMinSize.AutoSize = $true
$form.Controls.Add($lblMinSize)

$numMinSize = New-Object System.Windows.Forms.NumericUpDown
$numMinSize.Minimum = 0
$numMinSize.Maximum = 1000
$numMinSize.Value = 3
$numMinSize.Location = New-Object System.Drawing.Point(660,101)
$numMinSize.Size = New-Object System.Drawing.Size(60,20)
$form.Controls.Add($numMinSize)

$chkAllFormats.Add_CheckedChanged({
    foreach ($pattern in $script:scanFormatChecks.Keys) {
        $script:scanFormatChecks[$pattern].Checked = $chkAllFormats.Checked
    }
})

$lblMinSizeHint = New-Object System.Windows.Forms.Label
$lblMinSizeHint.Text = "Min size only filters Scan results (files smaller than this are skipped, not included) - drag-and-drop is never filtered."
$lblMinSizeHint.Location = New-Object System.Drawing.Point(10,124)
$lblMinSizeHint.AutoSize = $true
$form.Controls.Add($lblMinSizeHint)

$clb = New-Object System.Windows.Forms.ListView
$clb.Location = New-Object System.Drawing.Point(10,156)
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
$btnDelete.Location = New-Object System.Drawing.Point(10,331)
$btnDelete.Size = New-Object System.Drawing.Size(120,24)
$form.Controls.Add($btnDelete)

$btnClearList = New-Object System.Windows.Forms.Button
$btnClearList.Text = "Clear List"
$btnClearList.Location = New-Object System.Drawing.Point(140,331)
$btnClearList.Size = New-Object System.Drawing.Size(100,24)
$form.Controls.Add($btnClearList)

$lblDeleteHint = New-Object System.Windows.Forms.Label
$lblDeleteHint.Text = "3) Review your list. Click a row to select it, or Ctrl+A for all."
$lblDeleteHint.Location = New-Object System.Drawing.Point(250,335)
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

function Clear-FolderList {
    if ($script:running) { return }
    $count = $clb.Items.Count
    if ($count -eq 0) { return }
    $clb.Items.Clear()
    $script:folderData = @()
    $btnStart.Enabled = $false
    $lblStatus.Text = "Cleared $count entr$(if ($count -eq 1) {'y'} else {'ies'}) from the list."
    Add-Log $lblStatus.Text
}

$btnDelete.Add_Click({ Remove-SelectedFolderEntries })
$btnClearList.Add_Click({ Clear-FolderList })

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
$lblFormat.Text = "4) Output format:"
$lblFormat.Location = New-Object System.Drawing.Point(10,366)
$lblFormat.AutoSize = $true
$form.Controls.Add($lblFormat)

$cmbFormat = New-Object System.Windows.Forms.ComboBox
$cmbFormat.DropDownStyle = "DropDownList"
$cmbFormat.Items.AddRange(@("JPEG","WebP","PNG"))
$cmbFormat.SelectedIndex = 0
$cmbFormat.Location = New-Object System.Drawing.Point(110,363)
$cmbFormat.Size = New-Object System.Drawing.Size(80,22)
$form.Controls.Add($cmbFormat)

$lblQuality = New-Object System.Windows.Forms.Label
$lblQuality.Text = "Quality (1-100):"
$lblQuality.Location = New-Object System.Drawing.Point(210,366)
$lblQuality.AutoSize = $true
$form.Controls.Add($lblQuality)

$numQuality = New-Object System.Windows.Forms.NumericUpDown
$numQuality.Minimum = 1
$numQuality.Maximum = 100
$numQuality.Value = 90
$numQuality.Location = New-Object System.Drawing.Point(330,364)
$numQuality.Size = New-Object System.Drawing.Size(60,20)
$form.Controls.Add($numQuality)

$lblOutDirName = New-Object System.Windows.Forms.Label
$lblOutDirName.Text = "Output folder name:"
$lblOutDirName.Location = New-Object System.Drawing.Point(410,366)
$lblOutDirName.AutoSize = $true
$form.Controls.Add($lblOutDirName)

$txtOutDirName = New-Object System.Windows.Forms.TextBox
$txtOutDirName.Text = "converted_output"
$txtOutDirName.Location = New-Object System.Drawing.Point(535,363)
$txtOutDirName.Size = New-Object System.Drawing.Size(180,20)
$form.Controls.Add($txtOutDirName)

$cmbFormat.Add_SelectedIndexChanged({
    $isPng = ($cmbFormat.SelectedItem -eq "PNG")
    $numQuality.Enabled = -not $isPng
    $lblQuality.Enabled = -not $isPng
    $lblQuality.Text = if ($isPng) { "(PNG is lossless, no quality setting)" } else { "Quality (1-100):" }
})

$lblOutputHint = New-Object System.Windows.Forms.Label
$lblOutputHint.Text = "Saved to a new subfolder inside each source folder (named below) - or converted in place if Replace files is checked."
$lblOutputHint.Location = New-Object System.Drawing.Point(10,389)
$lblOutputHint.AutoSize = $true
$form.Controls.Add($lblOutputHint)

$lblParallel = New-Object System.Windows.Forms.Label
$lblParallel.Text = "Parallel jobs:"
$lblParallel.Location = New-Object System.Drawing.Point(10,423)
$lblParallel.AutoSize = $true
$form.Controls.Add($lblParallel)

$numParallel = New-Object System.Windows.Forms.NumericUpDown
$numParallel.Minimum = 1
$numParallel.Maximum = 32
$numParallel.Value = [Math]::Max(1, [Environment]::ProcessorCount)
$numParallel.Location = New-Object System.Drawing.Point(110,420)
$numParallel.Size = New-Object System.Drawing.Size(60,20)
$form.Controls.Add($numParallel)

$lblParallelHint = New-Object System.Windows.Forms.Label
$lblParallelHint.Text = "(runs this many conversions at once - big speedup on multi-core CPUs)"
$lblParallelHint.Location = New-Object System.Drawing.Point(180,423)
$lblParallelHint.AutoSize = $true
$form.Controls.Add($lblParallelHint)

$chkStrip = New-Object System.Windows.Forms.CheckBox
$chkStrip.Text = "Strip metadata (faster + smaller, drops EXIF/XMP/IPTC/color profile and other embedded metadata)"
$chkStrip.Checked = $false
$chkStrip.Location = New-Object System.Drawing.Point(10,446)
$chkStrip.AutoSize = $true
$form.Controls.Add($chkStrip)

$chkReplace = New-Object System.Windows.Forms.CheckBox
$chkReplace.Text = "Replace files in original folder (instead of a separate output folder)"
$chkReplace.Checked = $false
$chkReplace.Location = New-Object System.Drawing.Point(10,469)
$chkReplace.AutoSize = $true
$form.Controls.Add($chkReplace)

$chkBackupReplace = New-Object System.Windows.Forms.CheckBox
$chkBackupReplace.Text = "Back up originals first"
$chkBackupReplace.Checked = $true
$chkBackupReplace.Enabled = $false
$chkBackupReplace.Location = New-Object System.Drawing.Point(30,492)
$chkBackupReplace.AutoSize = $true
$form.Controls.Add($chkBackupReplace)

$lblReplaceWarn = New-Object System.Windows.Forms.Label
$lblReplaceWarn.Text = "(no safe-resume in this mode - every checked file gets reprocessed each run)"
$lblReplaceWarn.Location = New-Object System.Drawing.Point(190,495)
$lblReplaceWarn.AutoSize = $true
$form.Controls.Add($lblReplaceWarn)

$chkReplace.Add_CheckedChanged({
    $chkBackupReplace.Enabled = $chkReplace.Checked
    $chkBackupReplace.Checked = $chkReplace.Checked
})

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start"
$btnStart.Location = New-Object System.Drawing.Point(10,524)
$btnStart.Size = New-Object System.Drawing.Size(120,32)
$btnStart.Enabled = $false
$form.Controls.Add($btnStart)

$btnStop = New-Object System.Windows.Forms.Button
$btnStop.Text = "Stop"
$btnStop.Location = New-Object System.Drawing.Point(140,524)
$btnStop.Size = New-Object System.Drawing.Size(120,32)
$btnStop.Enabled = $false
$form.Controls.Add($btnStop)

$progressOverall = New-Object System.Windows.Forms.ProgressBar
$progressOverall.Location = New-Object System.Drawing.Point(10,564)
$progressOverall.Size = New-Object System.Drawing.Size(720,25)
$form.Controls.Add($progressOverall)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location = New-Object System.Drawing.Point(10,594)
$lblStatus.Size = New-Object System.Drawing.Size(720,20)
$lblStatus.Text = "Idle. Pick a root folder and click Scan."
$form.Controls.Add($lblStatus)

$txtLog = New-Object System.Windows.Forms.RichTextBox
$txtLog.ScrollBars = "Vertical"
$txtLog.Location = New-Object System.Drawing.Point(10,619)
$txtLog.Size = New-Object System.Drawing.Size(720,130)
$txtLog.ReadOnly = $true
$txtLog.Font = New-Object System.Drawing.Font("Consolas",9)
$form.Controls.Add($txtLog)

$script:cancelRequested = $false
$script:folderData = @()
$script:running = $false

function Add-Log([string]$msg, [bool]$isError = $false) {
    $line = "$(Get-Date -Format 'HH:mm:ss') $msg`r`n"
    $txtLog.SelectionStart = $txtLog.TextLength
    $txtLog.SelectionLength = 0
    $txtLog.SelectionColor = if ($isError) { [System.Drawing.Color]::Red } else { [System.Drawing.Color]::Black }
    $txtLog.AppendText($line)
    $txtLog.ScrollToCaret()
}

function Show-InfoPopup([string]$message, [string]$title) {
    $popup = New-Object System.Windows.Forms.Form
    $popup.Text = $title
    $popup.StartPosition = "CenterParent"
    $popup.FormBorderStyle = "FixedDialog"
    $popup.MaximizeBox = $false
    $popup.MinimizeBox = $false
    $popup.ShowInTaskbar = $false
    $popup.ClientSize = New-Object System.Drawing.Size(400,140)

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $message
    $lbl.Location = New-Object System.Drawing.Point(15,15)
    $lbl.Size = New-Object System.Drawing.Size(370,85)
    $popup.Controls.Add($lbl)

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "OK"
    $btnOk.Location = New-Object System.Drawing.Point(160,105)
    $btnOk.Size = New-Object System.Drawing.Size(80,28)
    $btnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $popup.Controls.Add($btnOk)
    $popup.AcceptButton = $btnOk

    [void]$popup.ShowDialog($form)
    $popup.Dispose()
}

function Get-RecommendedParallelJobs([string]$path) {
    $cpuCount = [Math]::Max(1, [Environment]::ProcessorCount)
    try {
        $driveLetter = (Resolve-Path -LiteralPath $path).Path.Substring(0,1)
        $partition = Get-Partition -DriveLetter $driveLetter -ErrorAction Stop
        $disk = Get-Disk -Number $partition.DiskNumber -ErrorAction Stop
        $physDisk = Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.DeviceId -eq $disk.Number } | Select-Object -First 1
        if ($physDisk.MediaType -eq "HDD") {
            return @{ Jobs = 2; Reason = "spinning HDD ($($disk.FriendlyName)) - low parallelism avoids disk-seek thrashing" }
        } elseif ($disk.BusType -eq "USB") {
            return @{ Jobs = [Math]::Min(6, $cpuCount); Reason = "external USB drive ($($disk.FriendlyName)) - moderate parallelism to avoid overloading it" }
        } else {
            return @{ Jobs = $cpuCount; Reason = "internal $($physDisk.MediaType) ($($disk.FriendlyName))" }
        }
    } catch {
        return @{ Jobs = $cpuCount; Reason = "could not detect drive type, defaulting to CPU core count" }
    }
}

$btnBrowse.Add_Click({
    $fbd = New-Object System.Windows.Forms.FolderBrowserDialog
    if (-not [string]::IsNullOrWhiteSpace($txtFolder.Text) -and (Test-Path $txtFolder.Text)) { $fbd.SelectedPath = $txtFolder.Text }
    if ($fbd.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $txtFolder.Text = $fbd.SelectedPath
    }
})

$btnScan.Add_Click({
    $root = $txtFolder.Text
    if ([string]::IsNullOrWhiteSpace($root) -or -not (Test-Path $root)) {
        [System.Windows.Forms.MessageBox]::Show("Folder not found: $root") | Out-Null
        return
    }
    Clear-FolderList
    $btnStart.Enabled = $false
    $lblStatus.Text = "Scanning..."
    [System.Windows.Forms.Application]::DoEvents()

    $recommended = Get-RecommendedParallelJobs $root
    if ([int]$numParallel.Value -ne $recommended.Jobs) {
        $numParallel.Value = [Math]::Min([Math]::Max($recommended.Jobs, $numParallel.Minimum), $numParallel.Maximum)
        Add-Log "Parallel jobs set to $($recommended.Jobs): $($recommended.Reason)"
    }

    $activePatterns = @($script:scanFormatChecks.Keys | Where-Object { $script:scanFormatChecks[$_].Checked })
    if ($activePatterns.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Check at least one format to scan for.") | Out-Null
        $lblStatus.Text = "Idle. Pick a root folder and click Scan."
        return
    }
    $extRegex = '^\.(' + ($activePatterns -join '|') + ')$'
    $minSizeBytes = [int64]($numMinSize.Value * 1MB)

    $files = Get-ChildItem -Path $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -match $extRegex -and
            $_.Length -ge $minSizeBytes -and
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
    if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
        Show-InfoPopup "ImageMagick's 'magick' command was not found on your PATH.`n`nInstall it from https://imagemagick.org/script/download.php and make sure 'Add application directory to your system path' is checked during setup, then restart this app." "ImageMagick not found"
        return
    }
    $checkedCount = @($clb.Items | Where-Object { $_.Checked }).Count
    if ($checkedCount -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No folders selected.") | Out-Null
        return
    }
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    if (-not $chkReplace.Checked -and ($txtOutDirName.Text.IndexOfAny($invalidChars) -ge 0)) {
        [System.Windows.Forms.MessageBox]::Show("Output folder name contains invalid characters (e.g. \ / : * ? `" < > |). Please fix it.") | Out-Null
        return
    }
    $script:cancelRequested = $false
    $script:running = $true
    $btnStart.Enabled = $false
    $btnStop.Enabled = $true
    $btnScan.Enabled = $false
    $btnBrowse.Enabled = $false
    $btnDelete.Enabled = $false
    $btnClearList.Enabled = $false
    $chkReplace.Enabled = $false
    $chkBackupReplace.Enabled = $false

    $selectedIndices = 0..($clb.Items.Count - 1) | Where-Object { $clb.Items[$_].Checked }
    $selectedFolders = $selectedIndices | ForEach-Object { $script:folderData[$_] }

    $allFiles = @()
    foreach ($fd in $selectedFolders) { $allFiles += $fd.Files }
    $total = $allFiles.Count
    $progressOverall.Maximum = [math]::Max($total,1)
    $progressOverall.Value = 0
    $done = 0
    $errCount = 0
    $origSizeBytes = 0
    $newSizeBytes = 0
    $quality = $numQuality.Value
    $format = $cmbFormat.SelectedItem.ToString()
    $ext = switch ($format) { "WebP" { ".webp" } "JPEG" { ".jpg" } "PNG" { ".png" } }
    $outDirName = $txtOutDirName.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($outDirName)) { $outDirName = "$($format.ToLower())_output" }
    $parallelJobs = [int]$numParallel.Value
    $stripMeta = $chkStrip.Checked
    $replaceMode = $chkReplace.Checked
    $backupBeforeReplace = $chkBackupReplace.Checked

    foreach ($fd in $selectedFolders) {
        if ($script:cancelRequested) { break }
        $dir = $fd.Path
        $tifFiles = $fd.Files
        Add-Log "=== $dir ($($tifFiles.Count) files) ==="
        [System.Windows.Forms.Application]::DoEvents()

        if ($replaceMode) {
            $outDir = $dir
            if ($backupBeforeReplace) {
                $backupDir = Join-Path $dir "_ORIGINAL_BACKUP"
                if (-not (Test-Path $backupDir)) {
                    New-Item -ItemType Directory -Path $backupDir | Out-Null
                    foreach ($f in $tifFiles) {
                        if ($script:cancelRequested) { break }
                        Copy-Item -LiteralPath $f.FullName -Destination $backupDir -ErrorAction SilentlyContinue
                        [System.Windows.Forms.Application]::DoEvents()
                    }
                    if (-not $script:cancelRequested) { Add-Log "  backed up originals: $backupDir" }
                } else {
                    Add-Log "  backup already exists, skipped: $backupDir"
                }
            }
        } else {
            $outDir = Join-Path $dir $outDirName
            if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
        }
        if ($script:cancelRequested) { break }

        $queue = New-Object System.Collections.Generic.Queue[object]
        foreach ($f in $tifFiles) { $queue.Enqueue($f) }
        $inFlight = @()

        while (($queue.Count -gt 0 -or $inFlight.Count -gt 0) -and -not $script:cancelRequested) {
            while ($inFlight.Count -lt $parallelJobs -and $queue.Count -gt 0) {
                $f = $queue.Dequeue()
                $outFile = Join-Path $outDir ($f.BaseName + $ext)
                if ((-not $replaceMode) -and (Test-Path $outFile)) {
                    $origSizeBytes += $f.Length
                    $newSizeBytes += (Get-Item $outFile).Length
                    $done++
                    $progressOverall.Value = [math]::Min($done, $total)
                    continue
                }
                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = "magick"
                $argParts = New-Object System.Collections.Generic.List[string]
                $argParts.Add("-limit"); $argParts.Add("thread"); $argParts.Add("1")
                $argParts.Add("-limit"); $argParts.Add("memory"); $argParts.Add("1GiB")
                $argParts.Add("-limit"); $argParts.Add("map"); $argParts.Add("2GiB")
                $argParts.Add("`"$($f.FullName)[0]`"")
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
                        Add-Log "  ERROR converting: $($job.File.Name)" $true
                        $errCount++
                    } else {
                        $origSizeBytes += $job.File.Length
                        $newSizeBytes += (Get-Item $job.OutFile).Length
                        if ($replaceMode -and ($job.OutFile -ne $job.File.FullName)) {
                            Remove-Item -LiteralPath $job.File.FullName -Force -ErrorAction SilentlyContinue
                        }
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

    $sizeSummary = ""
    if ($origSizeBytes -gt 0) {
        $origSizeMB = [math]::Round($origSizeBytes / 1MB, 1)
        $newSizeMB = [math]::Round($newSizeBytes / 1MB, 1)
        $savedPct = [math]::Round((1 - ($newSizeBytes / $origSizeBytes)) * 100, 1)
        $sizeSummary = " Size: $origSizeMB MB -> $newSizeMB MB ($savedPct% smaller)."
    }

    if ($script:cancelRequested) {
        $lblStatus.Text = "Stopped by user at $done/$total files.$sizeSummary"
    } else {
        $lblStatus.Text = "Done. $done/$total files processed, $errCount error(s).$sizeSummary"
    }
    Add-Log $lblStatus.Text ($errCount -gt 0)
    $progressOverall.Value = 0
    if ($script:cancelRequested) {
        Show-InfoPopup "Stopped at $done/$total files.$sizeSummary" "Stopped"
    } elseif ($errCount -gt 0) {
        Show-InfoPopup "Finished with $errCount error(s). $done/$total files processed.$sizeSummary`nSee the log for details." "Finished with errors"
    } else {
        Show-InfoPopup "All $total file(s) processed successfully.$sizeSummary" "Finished"
    }
    $script:running = $false
    $btnStart.Enabled = $true
    $btnStop.Enabled = $false
    $btnScan.Enabled = $true
    $btnBrowse.Enabled = $true
    $btnDelete.Enabled = $true
    $btnClearList.Enabled = $true
    $chkReplace.Enabled = $true
    $chkBackupReplace.Enabled = $chkReplace.Checked
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
