[CmdletBinding()]
param (
    [string]$SearchRoot = "build/windows/x64",
    [string[]]$ExeNames = @("link_tree.exe", "hk_drop.exe", "runner.exe"),
    [switch]$SelfCheck
)

if ($SelfCheck) {
    Write-Host "Running helper self-check test..."
    $testDir = Join-Path $env:TEMP "test_find_release_dir_$(Get-Random)"
    $subDir  = Join-Path $testDir "runner/Release"
    $dataDir = Join-Path $subDir "data"
    New-Item -ItemType Directory -Force -Path $dataDir | Out-Null
    Set-Content -Path (Join-Path $subDir "hk_drop.exe") -Value "dummy"
    Set-Content -Path (Join-Path $subDir "flutter_windows.dll") -Value "dummy"

    $found = Get-ChildItem -Path $testDir -Recurse -Directory -ErrorAction SilentlyContinue | Where-Object {
        $dir = $_.FullName
        $exeExists = $false
        foreach ($exe in $ExeNames) {
            if (Test-Path (Join-Path $dir $exe)) {
                $exeExists = $true
                break
            }
        }
        $dllExists  = Test-Path (Join-Path $dir "flutter_windows.dll")
        $dataExists = Test-Path (Join-Path $dir "data")
        $exeExists -and $dllExists -and $dataExists
    } | Select-Object -First 1

    Remove-Item -Recurse -Force $testDir -ErrorAction SilentlyContinue

    if ($found) {
        Write-Host "Self-check PASSED."
        exit 0
    } else {
        Write-Error "Self-check FAILED."
        exit 1
    }
}

# Ensure search root fallback
if (-not (Test-Path $SearchRoot)) {
    if (Test-Path "build/windows") {
        $SearchRoot = "build/windows"
    } elseif (Test-Path "build") {
        $SearchRoot = "build"
    } else {
        Write-Error "Search root directory does not exist: $SearchRoot"
        exit 1
    }
}

# Recursively find all directories under SearchRoot
$allDirs = @($SearchRoot)
$childDirs = Get-ChildItem -Path $SearchRoot -Recurse -Directory -ErrorAction SilentlyContinue
if ($childDirs) {
    $allDirs += ($childDirs | ForEach-Object { $_.FullName })
}

# 1. First Pass: Look for a directory that already contains exe, flutter_windows.dll, and data/
$validDir = $null

foreach ($dir in $allDirs) {
    $exeFound = $false
    foreach ($exe in $ExeNames) {
        if (Test-Path (Join-Path $dir $exe)) {
            $exeFound = $true
            break
        }
    }
    $dllExists  = Test-Path (Join-Path $dir "flutter_windows.dll")
    $dataExists = Test-Path (Join-Path $dir "data")

    if ($exeFound -and $dllExists -and $dataExists) {
        $validDir = $dir
        if ($dir -match "Release") {
            break
        }
    }
}

# 2. Second Pass: Find directory with executable, and auto-stage missing dll/data if needed
if (-not $validDir) {
    # Resolve Flutter SDK engine artifact cache directory locations
    $sdkCacheDirs = @()
    if ($env:FLUTTER_ROOT) {
        $sdkCacheDirs += Join-Path $env:FLUTTER_ROOT "bin/cache/artifacts/engine/windows-x64"
    }
    $flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($flutterCmd) {
        $flutterBin = Split-Path $flutterCmd.Source -Parent
        $flutterSdk = Split-Path $flutterBin -Parent
        $sdkCacheDirs += Join-Path $flutterSdk "bin/cache/artifacts/engine/windows-x64"
    }

    foreach ($dir in $allDirs) {
        $exeFound = $false
        foreach ($exe in $ExeNames) {
            if (Test-Path (Join-Path $dir $exe)) {
                $exeFound = $true
                break
            }
        }
        if ($exeFound) {
            Write-Host "Found executable target in directory: $dir. Validating and staging bundle dependencies..."

            # Stage flutter_windows.dll if missing
            $dllPath = Join-Path $dir "flutter_windows.dll"
            if (-not (Test-Path $dllPath)) {
                $dllSources = @(
                    "windows/flutter/ephemeral/flutter_windows.dll",
                    "build/windows/x64/flutter/flutter_windows.dll",
                    "build/windows/flutter/flutter_windows.dll",
                    "build/windows/x64/flutter/ephemeral/flutter_windows.dll"
                )
                foreach ($sdkCache in $sdkCacheDirs) {
                    $dllSources += Join-Path $sdkCache "flutter_windows.dll"
                }

                foreach ($src in $dllSources) {
                    if (Test-Path $src) {
                        Copy-Item $src -Destination $dir -Force
                        Write-Host "Auto-staged flutter_windows.dll from $src to $dir"
                        break
                    }
                }
            }

            # Stage data/ directory & assets if missing
            $dataPath = Join-Path $dir "data"
            if (-not (Test-Path $dataPath)) {
                New-Item -ItemType Directory -Force -Path $dataPath | Out-Null
            }

            $dataAssetsPath = Join-Path $dataPath "flutter_assets"
            if (-not (Test-Path $dataAssetsPath)) {
                $assetSources = @(
                    "build/flutter_assets",
                    "build/windows/flutter_assets",
                    "build/windows/x64/flutter_assets"
                )
                foreach ($src in $assetSources) {
                    if (Test-Path $src) {
                        New-Item -ItemType Directory -Force -Path $dataAssetsPath | Out-Null
                        Copy-Item "$src\*" -Destination $dataAssetsPath -Recurse -Force
                        Write-Host "Auto-staged flutter_assets from $src to $dataAssetsPath"
                        break
                    }
                }
            }

            $icuPath = Join-Path $dataPath "icudtl.dat"
            if (-not (Test-Path $icuPath)) {
                $icuSources = @(
                    "windows/flutter/ephemeral/icudtl.dat",
                    "build/windows/x64/flutter/icudtl.dat"
                )
                foreach ($sdkCache in $sdkCacheDirs) {
                    $icuSources += Join-Path $sdkCache "icudtl.dat"
                }

                foreach ($src in $icuSources) {
                    if (Test-Path $src) {
                        Copy-Item $src -Destination $dataPath -Force
                        Write-Host "Auto-staged icudtl.dat from $src to $dataPath"
                        break
                    }
                }
            }

            # Copy any compiled plugin DLLs if found in build directories
            $pluginDlls = Get-ChildItem -Path "build" -Recurse -Filter "*.dll" -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "flutter_windows.dll" }
            foreach ($pDll in $pluginDlls) {
                $destDll = Join-Path $dir $pDll.Name
                if (-not (Test-Path $destDll)) {
                    Copy-Item $pDll.FullName -Destination $dir -Force
                    Write-Host "Auto-staged plugin library $($pDll.Name) to $dir"
                }
            }

            # Re-verify directory completeness
            if ((Test-Path $dllPath) -and (Test-Path $dataPath)) {
                $validDir = $dir
                break
            }
        }
    }
}

if ($validDir) {
    $resolvedPath = (Resolve-Path $validDir).Path
    Write-Output $resolvedPath
    exit 0
} else {
    Write-Host "=== Diagnostic Log: Directories inspected under $SearchRoot ==="
    foreach ($dir in $allDirs) {
        $exes = ($ExeNames | Where-Object { Test-Path (Join-Path $dir $_) }) -join ", "
        $hasDll  = Test-Path (Join-Path $dir "flutter_windows.dll")
        $hasData = Test-Path (Join-Path $dir "data")
        Write-Host "Dir: $dir | Exes: [$exes] | DLL: $hasDll | Data: $hasData"
    }
    Write-Error "Could not locate a valid release directory containing ($($ExeNames -join ' | ')), flutter_windows.dll, and data/ under $SearchRoot"
    exit 1
}
