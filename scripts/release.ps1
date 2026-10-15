param(
    [switch]$major,
    [switch]$minor,
    [switch]$patch,
    [string]$m = '',
    [switch]$SkipPublish,
    [string]$ReleaseRepo = 'E:\Productivity\flutter\Apps\APPSRELEASE'
)

$ErrorActionPreference = 'Stop'
$originalDir = Get-Location
$projectRoot = Split-Path -Parent $PSScriptRoot

function Invoke-Git {
    param([string[]]$GitArguments)
    & git @GitArguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed: $($GitArguments -join ' ')" }
}

try {
    if (([int]$major.IsPresent + [int]$minor.IsPresent + [int]$patch.IsPresent) -gt 1) {
        throw 'Choose only one of -major, -minor, or -patch.'
    }
    Set-Location -LiteralPath $projectRoot
    if (-not $SkipPublish) {
        Invoke-Git -GitArguments @('-C', $ReleaseRepo, 'rev-parse', '--show-toplevel')
    }

    $pubspec = Join-Path $projectRoot 'pubspec.yaml'
    $content = [IO.File]::ReadAllText($pubspec)
    $versionMatch = [regex]::Match($content, '(?m)^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)[ \t]*\r?$')
    if (-not $versionMatch.Success) { throw 'Expected version: major.minor.patch+build in pubspec.yaml.' }
    $majorNum = [int]$versionMatch.Groups[1].Value
    $minorNum = [int]$versionMatch.Groups[2].Value
    $patchNum = [int]$versionMatch.Groups[3].Value
    $buildNum = [int]$versionMatch.Groups[4].Value
    if ($major) { $majorNum++; $minorNum = 0; $patchNum = 0 }
    elseif ($minor) { $minorNum++; $patchNum = 0 }
    elseif ($patch) { $patchNum++ }
    if ($major -or $minor -or $patch) { $buildNum++ }
    $versionName = "$majorNum.$minorNum.$patchNum"
    if ($major -or $minor -or $patch) {
        $updated = $content.Replace($versionMatch.Value.TrimEnd("`r"), "version: $versionName+$buildNum")
        [IO.File]::WriteAllText($pubspec, $updated, (New-Object Text.UTF8Encoding $false))
        Write-Host "Version updated to $versionName+$buildNum"
    }

    # A child process keeps the build script's location and environment changes isolated.
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectRoot 'build_installer.ps1')
    if ($LASTEXITCODE -ne 0) { throw 'Windows installer build failed. Nothing was published.' }
    $sourceFile = Join-Path $projectRoot 'dist\WMSWindowsListenerSetup.exe'
    if (-not (Test-Path -LiteralPath $sourceFile -PathType Leaf)) { throw 'Installer output was not found.' }
    if ($SkipPublish) {
        Write-Host "Installer ready: $sourceFile"
    } else {
        $projectName = Split-Path -Leaf $projectRoot
        $relativeFile = "$projectName/exe/$projectName-v$versionName.exe"
        $destination = Join-Path $ReleaseRepo $relativeFile
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        Copy-Item -LiteralPath $sourceFile -Destination $destination -Force
        Invoke-Git -GitArguments @('-C', $ReleaseRepo, 'add', '--', $relativeFile)
        & git -C $ReleaseRepo diff --cached --quiet -- $relativeFile
        $diffExit = $LASTEXITCODE
        if ($diffExit -eq 1) {
            $commitMsg = "release: $projectName v$versionName+$buildNum (exe)"
            if ($m) { $commitMsg += " - $m" }
            Invoke-Git -GitArguments @('-C', $ReleaseRepo, 'commit', '--only', '-m', $commitMsg, '--', $relativeFile)
        } elseif ($diffExit -ne 0) { throw 'Could not check staged installer changes.' }
        Invoke-Git -GitArguments @('-C', $ReleaseRepo, 'push')
        Write-Host "Published installer: $destination"
    }
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
} finally {
    Set-Location -LiteralPath $originalDir
}
