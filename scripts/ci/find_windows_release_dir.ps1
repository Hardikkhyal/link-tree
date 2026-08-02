[CmdletBinding()]
param (
    [string]$SearchRoot    = "build/windows/x64",
    [string[]]$ExeNames    = @("hk_drop.exe", "runner.exe"),
    [string]$OutputFile    = "",   # If set, resolved path is written here (avoids stdout capture issues)
    [switch]$AllowAnyExe,          # Fall back to any non-toolchain *.exe if named exes not found
    [switch]$SelfCheck
)

# ── Helper: is a directory a complete runnable bundle? ──────────────────────
function Test-IsCompleteBundle {
    param([string]$dir)
    $hasExe  = ($ExeNames | Where-Object { Test-Path (Join-Path $dir $_) }).Count -gt 0
    $hasDll  = Test-Path (Join-Path $dir "flutter_windows.dll")
    # Use chained Join-Path - forward-slash inside Join-Path is unreliable on Windows runners
    $hasData = (Test-Path (Join-Path $dir "data")) -or
               (Test-Path (Join-Path (Join-Path $dir "data") "flutter_assets"))
    return ($hasExe -and $hasDll -and $hasData)
}

# ── Helper: print what is present/missing in a dir ──────────────────────────
function Write-DirAudit {
    param([string]$dir)
    $exeHits = ($ExeNames | Where-Object { Test-Path (Join-Path $dir $_) }) -join ", "
    $hasDll  = Test-Path (Join-Path $dir "flutter_windows.dll")
    $hasData = (Test-Path (Join-Path $dir "data")) -or
               (Test-Path (Join-Path (Join-Path $dir "data") "flutter_assets"))
    Write-Host "  Dir : $dir"
    Write-Host "    Exe  : $(if ($exeHits) { $exeHits } else { 'MISSING' })"
    Write-Host "    DLL  : $(if ($hasDll)  { 'OK' } else { 'MISSING' })"
    Write-Host "    data : $(if ($hasData) { 'OK' } else { 'MISSING' })"
}

# ── Self-check mode ─────────────────────────────────────────────────────────
if ($SelfCheck) {
    Write-Host "Running helper self-check test..."
    $testDir    = Join-Path $env:TEMP "find_release_selfcheck_$(Get-Random)"
    $releaseDir = Join-Path (Join-Path $testDir "runner") "Release"
    $dataDir    = Join-Path (Join-Path $releaseDir "data") "flutter_assets"
    New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
    Set-Content -Path (Join-Path $releaseDir "hk_drop.exe")         -Value "dummy"
    Set-Content -Path (Join-Path $releaseDir "flutter_windows.dll") -Value "dummy"
    Set-Content -Path (Join-Path $dataDir    "AssetManifest.json")  -Value "{}"

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

# ── Resolve Flutter SDK engine cache (for DLL staging fallback) ─────────────
$sdkEngineDirs = @()
if ($env:FLUTTER_ROOT) {
    $sdkEngineDirs += Join-Path $env:FLUTTER_ROOT "bin\cache\artifacts\engine\windows-x64"
}
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    $flutterSdkRoot = Split-Path (Split-Path $flutterCmd.Source -Parent) -Parent
    $sdkEngineDirs += Join-Path $flutterSdkRoot "bin\cache\artifacts\engine\windows-x64"
}

# ── Step 1: check the KNOWN canonical Flutter CMake output paths first ───────
# These are hardcoded relative to CWD (the repo root), not derived from
# $SearchRoot. Flutter 3.x always writes the release binary here. Checking
# these explicitly avoids all path-algebra bugs.
$knownReleaseDirs = @(
    "build\windows\x64\runner\Release",
    "build\windows\runner\Release"
)

$validDir = $null

foreach ($rel in $knownReleaseDirs) {
    if (Test-Path $rel) {
        $absRel = (Resolve-Path $rel).Path
        Write-Host "Known release dir exists: $absRel"
        Write-DirAudit $absRel
        if (Test-IsCompleteBundle $absRel) {
            Write-Host "Known release dir is a complete bundle - no staging needed."
            $validDir = $absRel
            break
        } else {
            Write-Host "Known release dir is incomplete - will attempt staging here."
            # Pin exeDir to this location for staging; break after first found dir.
            $pinnedExeDir = $absRel
            break
        }
    }
}

# ── Step 2: if still not resolved, build candidate list from SearchRoot ──────
if (-not $validDir) {

    # Normalize $SearchRoot to an absolute path
    $searchFrom = $null
    foreach ($candidate in @($SearchRoot, "build\windows\x64", "build\windows", "build")) {
        if (Test-Path $candidate) {
            $searchFrom = (Resolve-Path $candidate).Path
            break
        }
    }

    if (-not $searchFrom) {
        Write-Error "Neither SearchRoot '$SearchRoot' nor fallback paths exist. Was the build run?"
        exit 1
    }
    Write-Host "Search root (absolute): $searchFrom"

    # Build unique absolute candidate list.
    # Sort: runner\Release dirs first, then any Release, then the rest.
    $candidateSet = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    $candidateSet.Add($searchFrom) | Out-Null
    $subDirs = Get-ChildItem $searchFrom -Recurse -Directory -ErrorAction SilentlyContinue
    if ($subDirs) {
        foreach ($sd in $subDirs) { $candidateSet.Add($sd.FullName) | Out-Null }
    }
    $candidateDirs = $candidateSet | Sort-Object {
        if ($_ -match '\\runner\\Release$') { 0 }
        elseif ($_ -match '\\Release$')     { 1 }
        elseif ($_ -match 'Release')        { 2 }
        else                                { 3 }
    }
    Write-Host "Phase 1: scanning $($candidateDirs.Count) candidate dirs..."

    foreach ($dir in $candidateDirs) {
        if (Test-IsCompleteBundle $dir) {
            Write-Host "FOUND complete bundle at: $dir"
            $validDir = $dir
            break
        }
    }
}

# ── Step 3: Stage missing assets into the exe directory ─────────────────────
if (-not $validDir) {
    Write-Host "=== Phase 2: No complete bundle found. Attempting to stage assets ==="

    # Determine exe directory: prefer pinned (known release dir), else scan candidates
    $exeDir = $pinnedExeDir
    if (-not $exeDir) {
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
    }

    # Fallback: any non-toolchain *.exe when -AllowAnyExe is set
    if (-not $exeDir -and $AllowAnyExe) {
        Write-Host "Named exe not found. Fallback: scanning for any *.exe under '$searchFrom'..."
        $toolPattern = '^(cmake|ctest|cpack|ninja|clang|clang\+\+|flutter|dart|pub|git|python|node|npm|msbuild|devenv|link|cl|rc|mt|signtool|makensis)(\.exe)?$'
        $anyExe = Get-ChildItem $searchFrom -Recurse -Filter "*.exe" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch $toolPattern } |
            Sort-Object { if ($_.DirectoryName -match '\\runner\\Release$') { 0 }
                          elseif ($_.DirectoryName -match 'Release') { 1 } else { 2 } } |
            Select-Object -First 1
        if ($anyExe) {
            $exeDir = $anyExe.DirectoryName
            Write-Host "Fallback: found exe '$($anyExe.Name)' in: $exeDir"
        }
    }

    if (-not $exeDir) {
        Write-Host ""
        Write-Host "ERROR (Build failure): No exe found."
        Write-Host "Searched for: $($ExeNames -join ', ')$(if ($AllowAnyExe) { ' + *.exe fallback' })"
        Write-Host ""
        Write-Host "=== Recursive listing under build\ ==="
        if (Test-Path "build") { Get-ChildItem "build" -Recurse | Select-Object FullName }
        exit 1
    }

    Write-Host "Exe directory: $exeDir"

    # Stage flutter_windows.dll if missing from exeDir.
    # Search order: same Release dir > sibling dirs in build tree (Release first) > SDK cache.
    $dllDest = Join-Path $exeDir "flutter_windows.dll"
    if (-not (Test-Path $dllDest)) {
        Write-Host "flutter_windows.dll missing - staging..."

        # Build ordered list of DLL candidates
        $dllSearchRoot = if ($searchFrom) { $searchFrom } else { "build" }
        $dllFound = Get-ChildItem $dllSearchRoot -Recurse -Filter "flutter_windows.dll" -ErrorAction SilentlyContinue |
            Sort-Object {
                if ($_.DirectoryName -match '\\runner\\Release$') { 0 }
                elseif ($_.DirectoryName -match 'Release')        { 1 }
                else                                              { 2 }
            } | Select-Object -First 1

        $dllSources = @()
        if ($dllFound) { $dllSources += $dllFound.FullName }
        $dllSources += "windows\flutter\ephemeral\flutter_windows.dll"
        foreach ($sdk in $sdkEngineDirs) {
            $dllSources += Join-Path $sdk "flutter_windows.dll"
        }

        $stagedDll = $false
        foreach ($src in $dllSources) {
            if ((Test-Path $src) -and ($src -ne $dllDest)) {
                Copy-Item $src -Destination $dllDest -Force
                Write-Host "Staged flutter_windows.dll from: $src"
                $stagedDll = $true
                break
            }
        }
        if (-not $stagedDll) { Write-Host "WARNING: Could not find flutter_windows.dll to stage." }
    } else {
        Write-Host "flutter_windows.dll already present in $exeDir"
    }

    # Stage data/ if missing from exeDir.
    $dataDest = Join-Path $exeDir "data"
    if (-not (Test-Path $dataDest)) {
        Write-Host "data/ missing - staging..."

        $dataSearchRoot = if ($searchFrom) { $searchFrom } else { "build" }

        # Prefer a data/ dir that contains flutter_assets, Release paths first
        $dataFound = Get-ChildItem $dataSearchRoot -Recurse -Directory -Filter "data" -ErrorAction SilentlyContinue |
            Where-Object { Test-Path (Join-Path $_.FullName "flutter_assets") } |
            Sort-Object {
                if ($_.FullName -match '\\runner\\Release\\') { 0 }
                elseif ($_.FullName -match 'Release')         { 1 }
                else                                          { 2 }
            } | Select-Object -First 1

        if ($dataFound) {
            New-Item -ItemType Directory -Force -Path $dataDest | Out-Null
            Copy-Item "$($dataFound.FullName)\*" -Destination $dataDest -Recurse -Force
            Write-Host "Staged data/ from: $($dataFound.FullName)"
        } else {
            # Fallback: look for a loose flutter_assets dir
            $assetsFound = Get-ChildItem $dataSearchRoot -Recurse -Directory -Filter "flutter_assets" -ErrorAction SilentlyContinue |
                Sort-Object {
                    if ($_.FullName -match '\\runner\\Release\\') { 0 }
                    elseif ($_.FullName -match 'Release')         { 1 }
                    else                                          { 2 }
                } | Select-Object -First 1

            if ($assetsFound) {
                $dataAssetsDest = Join-Path $dataDest "flutter_assets"
                New-Item -ItemType Directory -Force -Path $dataAssetsDest | Out-Null
                Copy-Item "$($assetsFound.FullName)\*" -Destination $dataAssetsDest -Recurse -Force
                Write-Host "Staged flutter_assets from: $($assetsFound.FullName)"
            } else {
                Write-Host "WARNING: Could not find data/ or flutter_assets to stage."
            }
        }
    } else {
        Write-Host "data/ already present in $exeDir"
    }

    # Stage plugin DLLs - restrict to files matching *_plugin.dll pattern or in the same Release dir.
    # Avoid indiscriminately copying build-system DLLs from intermediate directories.
    $pluginSearchRoot = if ($searchFrom) { $searchFrom } else { "build" }
    $pluginDlls = Get-ChildItem $pluginSearchRoot -Recurse -Filter "*_plugin.dll" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch "\\CMakeFiles\\" }
    foreach ($dll in $pluginDlls) {
        $dest = Join-Path $exeDir $dll.Name
        if (-not (Test-Path $dest)) {
            Copy-Item $dll.FullName -Destination $dest -Force
            Write-Host "Staged plugin DLL: $($dll.Name) from $($dll.FullName)"
        }
    }

    # Final validation
    if (Test-IsCompleteBundle $exeDir) {
        $validDir = $exeDir
        Write-Host "Phase 2 SUCCESS: complete bundle at $exeDir"
    } else {
        Write-Host ""
        Write-Host "ERROR (Packaging failure): Could not assemble complete bundle."
        Write-Host "Exe dir: $exeDir"
        Write-DirAudit $exeDir
        Write-Host ""
        Write-Host "=== Recursive listing: $exeDir ==="
        Get-ChildItem $exeDir -Recurse -ErrorAction SilentlyContinue | Select-Object FullName
        Write-Host ""
        Write-Host "=== Recursive listing: build\windows\x64 ==="
        if (Test-Path "build\windows\x64") {
            Get-ChildItem "build\windows\x64" -Recurse | Select-Object FullName
        }
        Write-Error "Packaging failure: missing flutter_windows.dll or data/ - see diagnostics above."
        exit 1
    }
}

# ── Output resolved path ─────────────────────────────────────────────────────
$resolvedPath = (Resolve-Path $validDir).Path
Write-Host "=== Release bundle ready: $resolvedPath ==="
Write-Host "Contents:"
Get-ChildItem $resolvedPath | ForEach-Object { Write-Host "  $($_.Name)" }

# Write to OutputFile (avoids stdout capture pollution) or emit directly to stdout.
if ($OutputFile -ne "") {
    Set-Content -Path $OutputFile -Value $resolvedPath -Encoding UTF8 -NoNewline
    Write-Host "Path written to: $OutputFile"
} else {
    [Console]::Out.WriteLine($resolvedPath)
}
exit 0
