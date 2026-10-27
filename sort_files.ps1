@echo off
cd /d "%~dp0"
set "SELF_PATH=%~f0"
set "SELF_NAME=%~nx0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$s = (Get-Content -LiteralPath $env:SELF_PATH | Select-Object -Skip 6) -join [Environment]::NewLine; Invoke-Expression $s"
goto :eof

# --- POWERSHELL CODE STARTS HERE ---
$currentDir = (Get-Location).Path
Write-Host "Sorting by extension in: $currentDir" -ForegroundColor Cyan

# Files and extensions to ALWAYS ignore ($env:SELF_NAME automatically ignores this .bat file)
$ignoredFiles = @('sort_files.ps1', 'Run_Sorter.bat', 'desktop.ini', $env:SELF_NAME)
$ignoredExtensions = @('.lnk', '.url', '.tmp', '.crdownload', '.part', '.opdownload')

$files = @(Get-ChildItem -LiteralPath $currentDir -File | Where-Object {
    $_.Extension.ToLower() -notin $ignoredExtensions -and $_.Name -notin $ignoredFiles
})

if ($files.Count -eq 0) {
    Exit
}

$counter = 0

foreach ($file in $files) {
    $counter++
    $percent = [math]::Round(($counter / $files.Count) * 100)
    Write-Progress -Activity "Sorting Files..." -Status "Moving $($file.Name)" -PercentComplete $percent

    # 1. Determine folder name
    $extension = $file.Extension.TrimStart('.').ToLower()
    
    if ([string]::IsNullOrWhiteSpace($extension)) {
        $extension = "_No_Extension"
    } elseif ([string]::IsNullOrWhiteSpace($file.BaseName)) {
        $extension = "_Dotfiles"
    }

    # 2. Create the target folder if it doesn't exist
    $targetFolder = Join-Path -Path $currentDir -ChildPath $extension
    if (-not (Test-Path -LiteralPath $targetFolder -PathType Container)) {
        try {
            $null = New-Item -Path $targetFolder -ItemType Directory -Force -ErrorAction Stop
        } catch {
            continue
        }
    }

    # 3. Resolve duplicate filenames safely (e.g., "photo (1).jpg")
    $destinationPath = Join-Path -Path $targetFolder -ChildPath $file.Name
    $duplicateCounter = 1
    
    while (Test-Path -LiteralPath $destinationPath) {
        if ([string]::IsNullOrWhiteSpace($file.BaseName)) {
            $newFileName = "{0} ({1})" -f $file.Name, $duplicateCounter
        } else {
            $newFileName = "{0} ({1}){2}" -f $file.BaseName, $duplicateCounter, $file.Extension
        }
        $destinationPath = Join-Path -Path $targetFolder -ChildPath $newFileName
        $duplicateCounter++
    }

    # 4. Move the file
    try {
        Move-Item -LiteralPath $file.FullName -Destination $destinationPath -ErrorAction Stop
    } catch {
        continue
    }
}

Write-Progress -Activity "Sorting Files..." -Completed
