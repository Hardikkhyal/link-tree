[CmdletBinding()]
param (
    [string]$SearchRoot = "build/windows/x64",
    [string[]]$ExeNames = @("hk_drop.exe", "runner.exe"),
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

if (-not (Test-Path $SearchRoot)) {
    Write-Error "Search root directory does not exist: $SearchRoot"
    exit 1
}

# Recursively find all directories under SearchRoot
$allDirs = @($SearchRoot)
$childDirs = Get-ChildItem -Path $SearchRoot -Recurse -Directory -ErrorAction SilentlyContinue
if ($childDirs) {
    $allDirs += ($childDirs | ForEach-Object { $_.FullName })
}

$validDir = $null

foreach ($dir in $allDirs) {
    $exeFound = $false
    foreach ($exe in $ExeNames) {
        $exePath = Join-Path $dir $exe
        if (Test-Path $exePath) {
            $exeFound = $true
            break
        }
    }
    $dllPath  = Join-Path $dir "flutter_windows.dll"
    $dataPath = Join-Path $dir "data"

    if ($exeFound -and (Test-Path $dllPath) -and (Test-Path $dataPath)) {
        $validDir = $dir
        if ($dir -match "Release") {
            break
        }
    }
}

if ($validDir) {
    $resolvedPath = (Resolve-Path $validDir).Path
    Write-Output $resolvedPath
    exit 0
} else {
    Write-Error "Could not locate a valid release directory containing ($($ExeNames -join ' | ')), flutter_windows.dll, and data/ under $SearchRoot"
    exit 1
}
