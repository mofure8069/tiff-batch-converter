# Image Batch Converter

A simple Windows GUI for batch-converting images (JPEG, PNG, GIF, BMP, TIFF, WebP) to JPEG, WebP, or PNG using [ImageMagick](https://imagemagick.org/).

![Image Batch Converter screenshot](screenshots/screenshot.png)

## Features

- Scans a folder tree and lists every subfolder containing JPEG/PNG/GIF/BMP/TIFF/WebP files, with file counts and sizes
- Pick which folders to include/exclude before converting
- Output formats: JPEG (default), WebP, PNG, with an adjustable quality setting (JPEG/WebP only — PNG is lossless)
- Files already in the target format are skipped automatically (no pointless re-encoding)
- Optional metadata stripping (drops EXIF/color profile for smaller, slightly faster output)
- Parallel conversion jobs — runs multiple `magick` processes at once to use all CPU cores
- Stop button kills in-flight conversions immediately
- Already-converted files are skipped automatically, so a run can be safely stopped and resumed later
- Output is written to a `<format>_output` subfolder next to each source folder; originals are never modified

## Requirements

- Windows with PowerShell
- [ImageMagick](https://imagemagick.org/script/download.php) installed and available on `PATH` as `magick`

## Usage

1. Double-click `Run_Converter.bat`
2. Browse to (or type) the root folder to scan
3. Click **Scan for image folders**
4. Uncheck any folders you don't want touched
5. Choose output format, quality, and parallel job count
6. Click **Start** — use **Stop** anytime to halt

## Files

- `TIF_to_WebP_Converter.ps1` — the GUI application
- `Run_Converter.bat` — launcher that runs the script with the right PowerShell execution policy

## Known limitations

- Windows-only (uses WinForms and `.bat`/`.ps1`)
- Requires `magick` to already be resolvable on `PATH`; the GUI doesn't check or install ImageMagick for you
- One quality setting applies to the whole batch — no per-file or per-folder overrides
- Parallel job count is a flat number of concurrent `magick` processes; it doesn't account for per-file size, so very large images plus a high job count can use a lot of memory at once

## License

[MIT](LICENSE)
