[CmdletBinding()]
param (
    [string]$SearchRoot    = "build/windows/x64",
    [string[]]$ExeNames    = @("hk_drop.exe", "runner.exe"),
    [string]$OutputFile    = "",   # If set, resolved path is written to this file (avoids stdout capture issues)
    [switch]$AllowAnyExe,          # If set, fall back to scanning for any *.exe when named exes are not found
    [switch]$SelfCheck
)

# Helper: check if a directory is a complete runnable bundle
function Test-IsCompleteBundle {
    param([string]$dir)
    $hasExe  = ($ExeNames | Where-Object { Test-Path (Join-Path $dir $_) }).Count -gt 0
    $hasDll  = Test-Path (Join-Path $dir "flutter_windows.dll")
    # Use chained Join-Path for nested paths - forward-slash inside Join-Path is unreliable on Windows runners
    $hasData = (Test-Path (Join-Path $dir "data")) -or (Test-Path (Join-Path (Join-Path $dir "data") "flutter_assets"))
    return ($hasExe -and $hasDll -and $hasData)
}

# Helper: print audit of what is missing in a dir
function Write-DirAudit {
    param([string]$dir)
    $exeHits = ($ExeNames | Where-Object { Test-Path (Join-Path $dir $_) }) -join ", "
    $hasDll  = Test-Path (Join-Path $dir "flutter_windows.dll")
    # Use chained Join-Path for nested paths - forward-slash inside Join-Path is unreliable on Windows runners
    $hasData = (Test-Path (Join-Path $dir "data")) -or (Test-Path (Join-Path (Join-Path $dir "data") "flutter_assets"))
    Write-Host "  Audit: $dir"
    Write-Host "    Exe  : $(if ($exeHits) { $exeHits } else { 'MISSING' })"
    Write-Host "    DLL  : $(if ($hasDll)  { 'OK' } else { 'MISSING' })"
    Write-Host "    data : $(if ($hasData) { 'OK' } else { 'MISSING' })"
}

# SelfCheck mode
if ($SelfCheck) {
    Write-Host "Running helper self-check test..."
    $testDir    = Join-Path $env:TEMP "find_release_selfcheck_$(Get-Random)"
    # Use chained Join-Path for nested paths - forward-slash inside Join-Path is unreliable on Windows runners
    $releaseDir = Join-Path (Join-Path $testDir "runner") "Release"
    $dataDir    = Join-Path (Join-Path $releaseDir "data") "flutter_assets"
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

# Resolve search root with fallbacks, then normalize to an absolute path.
# Relative paths passed through pwsh -File may resolve inconsistently when
# Get-ChildItem returns .FullName (always absolute) mixed with the relative root.
$searchFrom = "build"
if     (Test-Path $SearchRoot)             { $searchFrom = $SearchRoot }
elseif (Test-Path "build/windows/x64")    { $searchFrom = "build/windows/x64" }
elseif (Test-Path "build/windows")        { $searchFrom = "build/windows" }

# Normalize to absolute path so all candidateDirs entries are consistent.
if (Test-Path $searchFrom) {
    $searchFrom = (Resolve-Path $searchFrom).Path
}
Write-Host "Search root (absolute): $searchFrom"

# Canonical fast-path: check the standard Flutter CMake output location first.
# Build the path using $searchFrom's parent so it is always absolute.
$canonicalRelease = Join-Path (Join-Path (Split-Path $searchFrom -Parent) "x64") (Join-Path "runner" "Release")
# Also try the direct x64/runner/Release relative to searchFrom
$alt1 = Join-Path $searchFrom (Join-Path "x64" (Join-Path "runner" "Release"))
$alt2 = Join-Path $searchFrom (Join-Path "runner" "Release")
foreach ($cp in @($canonicalRelease, $alt1, $alt2)) {
    if (Test-Path $cp) {
        $cpAbs = (Resolve-Path $cp).Path
        Write-Host "Canonical fast-path found: $cpAbs"
        if (Test-IsCompleteBundle $cpAbs) {
            Write-Host "Canonical path is a complete bundle."
            $validDir = $cpAbs
        } else {
            Write-Host "Canonical path exists but is not yet a complete bundle - will attempt staging."
        }
        break
    }
}

# Build list of unique absolute directories to scan (used in Phase 1 and Phase 2).
# Deduplication prevents double-staging when the same dir appears under multiple aliases.
$candidateSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
if (Test-Path $searchFrom) {
    $candidateSet.Add($searchFrom) | Out-Null
    $subDirs = Get-ChildItem $searchFrom -Recurse -Directory -ErrorAction SilentlyContinue
    if ($subDirs) {
        foreach ($sd in $subDirs) { $candidateSet.Add($sd.FullName) | Out-Null }
    }
}
# Sort so Release directories are visited first - improves Phase 1 hit rate.
$candidateDirs = $candidateSet | Sort-Object { if ($_ -match '\\Release$') { 0 } elseif ($_ -match 'Release') { 1 } else { 2 } }
Write-Host "Candidate directories: $($candidateDirs.Count)"

if (-not $validDir) {
    Write-Host "=== Phase 1: Scanning $($candidateDirs.Count) candidate directories for complete bundle ==="
    foreach ($dir in $candidateDirs) {
        if (Test-IsCompleteBundle $dir) {
            Write-Host "FOUND complete bundle at: $dir"
            $validDir = $dir
            if ($dir -match "Release") { break }
        }
    }
}

# Phase 2: find the exe dir and stage missing assets alongside it
if (-not $validDir) {
    Write-Host "=== Phase 2: No complete bundle found. Attempting to stage assets ==="

    # Find where the named exe lives
    $exeDir = $null
    foreach ($dir in $candidateDirs) {
        foreach ($exe in $ExeNames) {
            if (Test-Path (Join-Path $dir $exe)) {
                $exeDir = $dir
                Write-Host "Found named exe '$exe' in: $dir"
                break
            }
        }
        if ($exeDir) { break }
    }

    # Fallback: scan for any *.exe when -AllowAnyExe is set and named exes were not found.
    # Excludes well-known build-tool executables (cmake, ninja, clang, dart, flutter, etc.)
    # so we don't accidentally treat a toolchain binary as the app executable.
    if (-not $exeDir -and $AllowAnyExe) {
        Write-Host "Named exe not found. Fallback: scanning for any *.exe under '$searchFrom'..."
        $toolExePattern = '^(cmake|ctest|cpack|ninja|clang|clang\+\+|flutter|dart|pub|git|python|node|npm|msbuild|devenv|link|cl|rc|mt|signtool|makensis)(\.exe)?$'
        $anyExe = Get-ChildItem $searchFrom -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch $toolExePattern } |
            Sort-Object { if ($_.DirectoryName -match 'Release') { 0 } else { 1 } } |
            Select-Object -First 1
        if ($anyExe) {
            $exeDir = $anyExe.DirectoryName
            Write-Host "Fallback: found exe '$($anyExe.Name)' in: $exeDir"
        }
    }

    if (-not $exeDir) {
        Write-Host "ERROR (Build failure): No exe found at all under '$searchFrom'."
        Write-Host "This means flutter build windows --release failed or the exe was not written."
        Write-Host "Searched for: $($ExeNames -join ', ')$(if ($AllowAnyExe) { ' + any *.exe fallback' })"
        Write-Host ""
        Write-Host "=== Full recursive listing under '$searchFrom' ==="
        if (Test-Path $searchFrom) {
            Get-ChildItem $searchFrom -Recurse | Select-Object FullName
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
        # Search the build tree for flutter_windows.dll, preferring Release-path copies.
        $found = Get-ChildItem $searchFrom -Recurse -Filter "flutter_windows.dll" -ErrorAction SilentlyContinue |
            Sort-Object { if ($_.DirectoryName -match '\\Release$') { 0 } elseif ($_.DirectoryName -match 'Release') { 1 } else { 2 } } |
            Select-Object -First 1
        if ($found) {
            Write-Host "Found flutter_windows.dll candidate: $($found.FullName)"
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
        # Search the build tree for data/ dir containing flutter_assets, preferring Release paths.
        $dataFound = Get-ChildItem $searchFrom -Recurse -Directory -Filter "data" -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "flutter_assets") } |
            Sort-Object { if ($_.FullName -match '\\Release\\') { 0 } elseif ($_.FullName -match 'Release') { 1 } else { 2 } } |
            Select-Object -First 1
        if ($dataFound) {
            New-Item -ItemType Directory -Force -Path $dataDest | Out-Null
            Copy-Item "$($dataFound.FullName)\*" -Destination $dataDest -Recurse -Force
            Write-Host "Staged data/ from: $($dataFound.FullName)"
        } else {
            # Fallback: search for flutter_assets directory directly, preferring Release paths.
            $assetsFound = Get-ChildItem $searchFrom -Recurse -Directory -Filter "flutter_assets" -ErrorAction SilentlyContinue |
                Sort-Object { if ($_.FullName -match '\\Release\\') { 0 } elseif ($_.FullName -match 'Release') { 1 } else { 2 } } |
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

    # Stage any plugin DLLs found under searchFrom
    $pluginDlls = Get-ChildItem $searchFrom -Recurse -Filter "*.dll" -ErrorAction SilentlyContinue |
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
Get-ChildItem $resolvedPath | ForEach-Object { Write-Host "  $($_.Name)" }

# Write the path to OutputFile when specified - avoids stdout capture pollution entirely.
# When -OutputFile is not set, emit one line to stdout for backward compatibility.
if ($OutputFile -ne "") {
    Set-Content -Path $OutputFile -Value $resolvedPath -Encoding UTF8 -NoNewline
    Write-Host "Path written to: $OutputFile"
} else {
    # Emit ONLY the path on stdout (no other Write-Output calls anywhere above)
    [Console]::Out.WriteLine($resolvedPath)
}
exit 0
