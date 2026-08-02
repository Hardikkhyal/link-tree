[CmdletBinding()]
param (
    [string]$SearchRoot    = "build/windows/x64",
    [string[]]$ExeNames    = @("hk_drop.exe", "runner.exe"),
    [switch]$SelfCheck
)

# Helper: check if a directory is a complete runnable bundle
function Test-IsCompleteBundle {
    param([string]$dir)
    $hasExe  = ($ExeNames | Where-Object { Test-Path (Join-Path $dir $_) }).Count -gt 0
    $hasDll  = Test-Path (Join-Path $dir "flutter_windows.dll")
    $hasData = (Test-Path (Join-Path $dir "data")) -or (Test-Path (Join-Path $dir "data/flutter_assets"))
    return ($hasExe -and $hasDll -and $hasData)
}

# Helper: print audit of what is missing in a dir
function Write-DirAudit {
    param([string]$dir)
    $exeHits = ($ExeNames | Where-Object { Test-Path (Join-Path $dir $_) }) -join ", "
    $hasDll  = Test-Path (Join-Path $dir "flutter_windows.dll")
    $hasData = (Test-Path (Join-Path $dir "data")) -or (Test-Path (Join-Path $dir "data/flutter_assets"))
    Write-Host "  Audit: $dir"
    Write-Host "    Exe  : $(if ($exeHits) { $exeHits } else { 'MISSING' })"
    Write-Host "    DLL  : $(if ($hasDll)  { 'OK' } else { 'MISSING' })"
    Write-Host "    data : $(if ($hasData) { 'OK' } else { 'MISSING' })"
}

# SelfCheck mode
if ($SelfCheck) {
    Write-Host "Running helper self-check test..."
    $testDir    = Join-Path $env:TEMP "find_release_selfcheck_$(Get-Random)"
    $releaseDir = Join-Path $testDir "runner/Release"
    $dataDir    = Join-Path $releaseDir "data/flutter_assets"
    New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
    Set-Content -Path (Join-Path $releaseDir "hk_drop.exe")          -Value "dummy"
    Set-Content -Path (Join-Path $releaseDir "flutter_windows.dll")  -Value "dummy"
    Set-Content -Path (Join-Path $dataDir    "AssetManifest.json")   -Value "{}"

    $result = Test-IsCompleteBundle $releaseDir
    Remove-Item -Recurse -Force $testDir -ErrorAction SilentlyContinue

    if ($result) {
        Write-Host "Self-check PASSED."
        exit 0
    } else {
        Write-Error "Self-check FAILED - complete bundle not detected."
        exit 1
    }
}

# Resolve Flutter SDK engine cache directories
$sdkEngineDirs = @()
if ($env:FLUTTER_ROOT) {
    $sdkEngineDirs += Join-Path $env:FLUTTER_ROOT "bin/cache/artifacts/engine/windows-x64"
}
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    $flutterSdkRoot = Split-Path (Split-Path $flutterCmd.Source -Parent) -Parent
    $sdkEngineDirs += Join-Path $flutterSdkRoot "bin/cache/artifacts/engine/windows-x64"
}

# Resolve search root with fallbacks
$searchFrom = "build"
if (Test-Path $SearchRoot)             { $searchFrom = $SearchRoot }
elseif (Test-Path "build/windows/x64") { $searchFrom = "build/windows/x64" }
elseif (Test-Path "build/windows")     { $searchFrom = "build/windows" }

# Build list of all directories to scan
$candidateDirs = @()
if (Test-Path $searchFrom) {
    $candidateDirs += $searchFrom
    $subDirs = Get-ChildItem $searchFrom -Recurse -Directory -ErrorAction SilentlyContinue
    if ($subDirs) { $candidateDirs += $subDirs.FullName }
}

Write-Host "=== Phase 1: Scanning $($candidateDirs.Count) candidate directories for complete bundle ==="
$validDir = $null

foreach ($dir in $candidateDirs) {
    if (Test-IsCompleteBundle $dir) {
        Write-Host "FOUND complete bundle at: $dir"
        $validDir = $dir
        if ($dir -match "Release") { break }
    }
}

# Phase 2: find the exe dir and stage missing assets alongside it
if (-not $validDir) {
    Write-Host "=== Phase 2: No complete bundle found. Attempting to stage assets ==="

    # Find where the exe lives
    $exeDir = $null
    foreach ($dir in $candidateDirs) {
        foreach ($exe in $ExeNames) {
            if (Test-Path (Join-Path $dir $exe)) {
                $exeDir = $dir
                Write-Host "Found exe in: $dir"
                break
            }
        }
        if ($exeDir) { break }
    }

    if (-not $exeDir) {
        Write-Host "ERROR (Build failure): No exe found at all under '$searchFrom'."
        Write-Host "This means flutter build windows failed or the exe was not written."
        Write-Host ""
        Write-Host "=== Full recursive listing under build/ ==="
        if (Test-Path "build") {
            Get-ChildItem "build" -Recurse | Select-Object FullName
        }
        exit 1
    }

    # Stage flutter_windows.dll if missing
    $dllDest = Join-Path $exeDir "flutter_windows.dll"
    if (-not (Test-Path $dllDest)) {
        Write-Host "flutter_windows.dll missing from exe dir - attempting to stage it..."
        $dllCandidates = @("windows/flutter/ephemeral/flutter_windows.dll")
        foreach ($sdkEngDir in $sdkEngineDirs) {
            $dllCandidates += Join-Path $sdkEngDir "flutter_windows.dll"
        }
        # Search the whole build tree for flutter_windows.dll
        $found = Get-ChildItem "build" -Recurse -Filter "flutter_windows.dll" -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) {
            $dllCandidates = @($found.FullName) + $dllCandidates
        }

        $staged = $false
        foreach ($src in $dllCandidates) {
            if ((Test-Path $src) -and ($src -ne $dllDest)) {
                Copy-Item $src -Destination $dllDest -Force
                Write-Host "Staged flutter_windows.dll from: $src"
                $staged = $true
                break
            }
        }
        if (-not $staged) {
            Write-Host "WARNING: Could not find flutter_windows.dll to stage."
        }
    }

    # Stage data/ (flutter assets) if missing
    $dataDest = Join-Path $exeDir "data"
    if (-not (Test-Path $dataDest)) {
        Write-Host "data/ directory missing from exe dir - attempting to stage it..."
        # Search the whole build tree for data/ dir containing flutter_assets
        $dataFound = Get-ChildItem "build" -Recurse -Directory -Filter "data" -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "flutter_assets") } |
            Select-Object -First 1
        if ($dataFound) {
            New-Item -ItemType Directory -Force -Path $dataDest | Out-Null
            Copy-Item "$($dataFound.FullName)\*" -Destination $dataDest -Recurse -Force
            Write-Host "Staged data/ from: $($dataFound.FullName)"
        } else {
            # Fallback: search for flutter_assets directory directly
            $assetsFound = Get-ChildItem "build" -Recurse -Directory -Filter "flutter_assets" -ErrorAction SilentlyContinue |
                Select-Object -First 1
            if ($assetsFound) {
                $dataAssetsDest = Join-Path $dataDest "flutter_assets"
                New-Item -ItemType Directory -Force -Path $dataAssetsDest | Out-Null
                Copy-Item "$($assetsFound.FullName)\*" -Destination $dataAssetsDest -Recurse -Force
                Write-Host "Staged flutter_assets from: $($assetsFound.FullName)"
            } else {
                Write-Host "WARNING: Could not find data/ or flutter_assets to stage."
            }
        }
    }

    # Stage any plugin DLLs found in the build tree
    $pluginDlls = Get-ChildItem "build" -Recurse -Filter "*.dll" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "flutter_windows.dll" -and $_.FullName -notmatch "\\x64\\flutter\\" }
    foreach ($dll in $pluginDlls) {
        $dest = Join-Path $exeDir $dll.Name
        if (-not (Test-Path $dest)) {
            Copy-Item $dll.FullName -Destination $dest -Force
            Write-Host "Staged plugin DLL: $($dll.Name)"
        }
    }

    if (Test-IsCompleteBundle $exeDir) {
        $validDir = $exeDir
        Write-Host "Phase 2 SUCCESS: staged complete bundle at $exeDir"
    } else {
        Write-Host ""
        Write-Host "ERROR (Packaging failure): Could not assemble complete bundle."
        Write-Host "All candidate directories:"
        foreach ($dir in $candidateDirs) { Write-DirAudit $dir }
        Write-Host ""
        Write-Host "=== Recursive listing: build/windows/x64 ==="
        if (Test-Path "build/windows/x64") {
            Get-ChildItem "build/windows/x64" -Recurse | Select-Object FullName
        }
        Write-Error "Packaging failure: missing flutter_windows.dll or data/ - see diagnostics above."
        exit 1
    }
}

# Output resolved path
$resolvedPath = (Resolve-Path $validDir).Path
Write-Host "=== Release bundle ready at: $resolvedPath ==="
Write-Host "Contents:"
Get-ChildItem $resolvedPath | Select-Object Name, Length
Write-Output $resolvedPath
exit 0
