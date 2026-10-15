$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$env:PUB_CACHE = Join-Path $PSScriptRoot '.tools\pub_cache'
$env:TEMP = Join-Path $PSScriptRoot '.tools\tmp'
$env:TMP = $env:TEMP
New-Item -ItemType Directory -Force -Path $env:PUB_CACHE,$env:TEMP | Out-Null

flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get gagal' }
flutter build windows --release
if ($LASTEXITCODE -ne 0) { throw 'flutter build windows gagal' }

$releaseDir = Join-Path $PSScriptRoot 'build\windows\x64\runner\Release'
$redistRoot = 'C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Redist\MSVC'
$redistDir = Get-ChildItem -LiteralPath $redistRoot -Directory -ErrorAction SilentlyContinue |
  Sort-Object Name -Descending |
  ForEach-Object { Join-Path $_.FullName 'x64\Microsoft.VC143.CRT' } |
  Where-Object { Test-Path -LiteralPath $_ } |
  Select-Object -First 1
if (-not $redistDir) { throw 'Visual C++ Redistributable x64 tidak ditemukan pada instalasi Visual Studio.' }
foreach ($name in @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')) {
  Copy-Item -LiteralPath (Join-Path $redistDir $name) -Destination $releaseDir -Force
}

$compiler = Get-Command makensis.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -First 1
if (-not $compiler) {
  $compiler = Join-Path $PSScriptRoot '.tools\nsis-3.12\makensis.exe'
}
if (-not (Test-Path -LiteralPath $compiler)) { throw 'makensis.exe tidak ditemukan. Unduh NSIS lalu lihat README.md.' }
New-Item -ItemType Directory -Force -Path (Join-Path $PSScriptRoot 'dist') | Out-Null
$versionLine = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'pubspec.yaml') | Where-Object { $_ -match '^version:' }
if ($versionLine -notmatch '^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') { throw 'Invalid version in pubspec.yaml.' }
$appVersion = $Matches[1]
& $compiler "/DAPP_VERSION=$appVersion" 'installer\wms_windows_listener.nsi'
if ($LASTEXITCODE -ne 0) { throw 'Pembuatan installer gagal' }
Write-Host "Installer siap: $PSScriptRoot\dist\WMSWindowsListenerSetup.exe"
