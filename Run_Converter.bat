@echo off
where magick >nul 2>nul
if errorlevel 1 (
    powershell -NoProfile -WindowStyle Hidden -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.MessageBox]::Show('ImageMagick (the magick command) was not found on your PATH.' + [Environment]::NewLine + [Environment]::NewLine + 'Install it first, then run this app again:' + [Environment]::NewLine + '  winget install ImageMagick.ImageMagick' + [Environment]::NewLine + [Environment]::NewLine + 'Or download it from https://imagemagick.org/script/download.php' + [Environment]::NewLine + [Environment]::NewLine + 'Make sure to check ''Add application directory to your system path'' during setup, then restart this app.', 'ImageMagick Required', 'OK', 'Warning') | Out-Null"
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0image-batch-converter.ps1"
