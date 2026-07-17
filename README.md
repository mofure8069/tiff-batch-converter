# Image Batch Converter

A simple Windows GUI for batch-converting images (JPEG, PNG, GIF, BMP, TIFF, WebP) to JPEG, WebP, or PNG using [ImageMagick](https://imagemagick.org/).

![Image Batch Converter screenshot](screenshots/screenshot.png)

## Features

- Scans a folder tree and lists every subfolder containing JPEG/PNG/GIF/BMP/TIFF/WebP files, with file counts and sizes. A **Min size (MB)** field (default 3) filters out small files during scanning — set it to 0 to disable. An **All** checkbox toggles every format checkbox at once (off by default)
- Or just drag individual files or folders straight into the list — no scan required, and the size filter doesn't apply to drops
- Pick which folders to include/exclude before converting
- Select rows (click, Ctrl+click, Shift+click, or Ctrl+A) and click **Delete Selected** to remove entries from the list, or **Clear List** to empty it entirely
- Output formats: JPEG (default), WebP, PNG, with an adjustable quality setting (JPEG/WebP only — PNG is lossless)
- Optional metadata stripping (drops EXIF/color profile for smaller, slightly faster output)
- Parallel conversion jobs — runs multiple `magick` processes at once. Scanning auto-detects the target drive and picks a sensible default: full CPU core count on an internal SSD/NVMe drive, a moderate count on external USB drives, or just 2 on a spinning HDD (more parallelism there just causes disk-seek thrashing, not speed) — always manually adjustable
- Each `magick` process is capped with `-limit thread 1 -limit memory 1GiB -limit map 2GiB` to keep total RAM/CPU use predictable when many run in parallel
- Stop button kills in-flight conversions immediately
- Error lines in the log are highlighted in red; a popup confirms when a run finishes or is stopped, and the progress bar resets afterward
- Finish summary reports total size before vs. after and the percent saved
- Already-converted files are skipped automatically, so a run can be safely stopped and resumed later
- Output is written to a subfolder next to each source folder by default (name editable via **Output folder name**, defaults to `converted_output` — useful since one folder can hold a mix of original formats), so originals are never touched
- Or check **Replace files in original folder** to convert files in place: on success, the original is deleted and the converted file takes its place in the same folder (even if the extension changes, e.g. `.jpeg` → `.jpg`) — optionally backing up originals to `_ORIGINAL_BACKUP` first (on by default when this mode is used). Note: this mode always reprocesses every checked file on each run, since there's no separate output location to check for "already done"

## Requirements

- Windows with PowerShell
- [ImageMagick](https://imagemagick.org/script/download.php) installed and available on `PATH` as `magick`. Easiest way: `winget install ImageMagick.ImageMagick`, or run the installer and make sure **"Add application directory to your system path"** is checked. The app will show a clear error on Start if `magick` isn't found — restart it after installing so the updated PATH takes effect

## Usage

1. Double-click `Run_Converter.bat` — it checks for ImageMagick on your PATH first and shows install instructions instead of launching if it's missing
2. Browse to (or type) the root folder
3. Check which formats to scan for (or check **All**), optionally set a **Min size (MB)** to skip small files, then click **Scan for image folders** — or skip scanning entirely and just drag files/folders straight into the list
4. Uncheck any folders you don't want touched, or use **Delete Selected** (after selecting rows) / **Clear List** to remove entries
5. Choose output format, quality, parallel job count, and output folder name — or check **Replace files in original folder** to convert in place instead of using a separate output folder
6. Click **Start** — use **Stop** anytime to halt

## Files

- `image-batch-converter.ps1` — the GUI application
- `Run_Converter.bat` — launcher that runs the script with the right PowerShell execution policy

## Known limitations

- Windows-only (uses WinForms and `.bat`/`.ps1`)
- Requires ImageMagick to be installed separately; the app checks for it and shows install instructions, but doesn't install it for you
- One quality setting applies to the whole batch — no per-file or per-folder overrides
- Parallel job count is a flat number of concurrent `magick` processes; it doesn't account for per-file size, so very large images plus a high job count can use a lot of memory at once

## License

[MIT](LICENSE)
