<#
.SYNOPSIS
  Builds Fermata for Windows (x64) and creates dist\setup.exe with Inno Setup 6.

.DESCRIPTION
  1. flutter build windows --release            (skip with -SkipBuild)
  2. stages build\windows\x64\runner\Release plus the Visual C++ runtime DLLs
     (msvcp140.dll, vcruntime140.dll, vcruntime140_1.dll; Flutter does not ship
     them and a clean Windows installation may not have them)
  3. ISCC.exe /DAppVersion=<ver> /DSourceDir=<stage> packaging\windows\fermata.iss
     -> dist\setup.exe

  Requirements: Flutter 3.47.8, Visual Studio 2022 with "Desktop development
  with C++", Rust (rustup; smtc_windows builds through cargokit), Inno Setup 6.3+
  (winget install JRSoftware.InnoSetup  or  choco install innosetup -y).

.PARAMETER SkipBuild
  Package the existing build\windows\x64\runner\Release.

.PARAMETER DartDefineFromFile
  JSON/.env file with build-time defines (developer credentials, docs\BUILDING.md).

.PARAMETER Iscc
  Path to ISCC.exe (default: search PATH, the standard install folders and the registry).

.PARAMETER OutputDir
  Output directory (default: dist).

.PARAMETER SignCommand
  Optional Inno Setup sign tool command ($f = file to sign, $q = a double quote;
  do not use literal double quotes), e.g.
  '$qC:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x64\signtool.exe$q sign /fd sha256 /tr http://timestamp.digicert.com /td sha256 /f $qC:\certs\fermata.pfx$q /p $qsecret$q $f'
  Signs fermata.exe, setup.exe and the uninstaller (docs\RELEASING.md).
  Default: $env:FERMATA_SIGN_COMMAND. -DartDefineFromFile defaults to
  $env:FERMATA_DART_DEFINES_FILE.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tool\package_windows.ps1
#>
[CmdletBinding()]
param(
    [switch]$SkipBuild,
    [string]$DartDefineFromFile = $env:FERMATA_DART_DEFINES_FILE,
    [string]$Iscc,
    [string]$OutputDir = 'dist',
    [string]$SignCommand = $env:FERMATA_SIGN_COMMAND
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Ok([string]$Message) { Write-Host "  ok $Message" -ForegroundColor Green }
function Write-Warn([string]$Message) {
    Write-Warning $Message
    if ($env:GITHUB_ACTIONS -eq 'true') { Write-Host "::warning::$Message" }
}
function Fail([string]$Message) {
    if ($env:GITHUB_ACTIONS -eq 'true') { Write-Host "::error::$Message" }
    throw $Message
}

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root

# --- Version from pubspec.yaml ("1.2.3+45" -> 1.2.3 and 1.2.3.45) ---------------
$match = Select-String -Path (Join-Path $Root 'pubspec.yaml') -Pattern '^version:\s*([^\s#]+)' | Select-Object -First 1
if (-not $match) { Fail 'No version: line in pubspec.yaml' }
$fullVersion = $match.Matches[0].Groups[1].Value
$version = ($fullVersion -split '\+')[0]
$buildNumber = '0'
if ($fullVersion -match '\+(\d+)$') { $buildNumber = $Matches[1] }
if ($version -notmatch '^(\d+)\.(\d+)\.(\d+)') { Fail "Unexpected version '$fullVersion' in pubspec.yaml" }
$numericVersion = '{0}.{1}.{2}.{3}' -f $Matches[1], $Matches[2], $Matches[3], $buildNumber
Write-Step "Fermata $version (file version $numericVersion), Windows x64"

# --- Build -------------------------------------------------------------------------
if (-not $SkipBuild) {
    if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) { Fail 'flutter is not on PATH' }
    $flutterArgs = @('build', 'windows', '--release')
    if ($DartDefineFromFile) {
        if (-not (Test-Path $DartDefineFromFile)) { Fail "dart-define file not found: $DartDefineFromFile" }
        $flutterArgs += "--dart-define-from-file=$DartDefineFromFile"
    }
    Write-Step ("flutter " + ($flutterArgs -join ' '))
    & flutter @flutterArgs
    if ($LASTEXITCODE -ne 0) { Fail "flutter build windows failed (exit $LASTEXITCODE)" }
} else {
    Write-Step 'Skipping flutter build (-SkipBuild)'
}

$bundle = Join-Path $Root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $bundle 'fermata.exe'))) { Fail "$bundle\fermata.exe not found" }
if (-not (Test-Path (Join-Path $bundle 'flutter_windows.dll'))) { Fail "$bundle is incomplete (flutter_windows.dll missing)" }
if (-not (Test-Path (Join-Path $bundle 'data\app.so'))) { Fail "$bundle is not a release build (data\app.so missing)" }

# --- Stage the bundle + Visual C++ runtime ------------------------------------------
$stage = Join-Path $Root 'build\windows\x64\installer-stage'
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
Copy-Item -Recurse -Path $bundle -Destination $stage

$crtDlls = @('msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll')
$crtDir = $null
$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
if (Test-Path $vswhere) {
    $vsPath = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($vsPath) {
        $crtDir = Get-ChildItem -Path (Join-Path $vsPath 'VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT') -Directory -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending | Select-Object -First 1
    }
}
foreach ($dll in $crtDlls) {
    $src = $null
    if ($crtDir -and (Test-Path (Join-Path $crtDir.FullName $dll))) { $src = Join-Path $crtDir.FullName $dll }
    elseif (Test-Path (Join-Path $env:SystemRoot "System32\$dll")) { $src = Join-Path $env:SystemRoot "System32\$dll" }
    if ($src) {
        Copy-Item -Force $src (Join-Path $stage $dll)
    } else {
        Write-Warn "$dll not found (install the Visual Studio C++ workload); setup.exe will rely on the user's VC++ runtime"
    }
}
if ($crtDir) { Write-Ok "VC++ runtime from $($crtDir.FullName)" } else { Write-Ok 'VC++ runtime from System32' }

# --- Branding files the installer script needs --------------------------------------
foreach ($f in @('installer_icon.ico', 'wizard_image.bmp', 'wizard_small.bmp')) {
    if (-not (Test-Path (Join-Path $Root "packaging\windows\$f"))) { Fail "packaging\windows\$f is missing (branding)" }
}

# CompanyName / ProductName decide %APPDATA%\<CompanyName>\<ProductName> (path_provider);
# the uninstaller's "remove my data" option must delete exactly that folder.
$rc = Get-Content -Raw -Path (Join-Path $Root 'windows\runner\Runner.rc')
$dataCompany = 'Fermata'
$dataProduct = 'Fermata'
if ($rc -match 'VALUE\s+"CompanyName",\s*"([^"]*)"') { $dataCompany = $Matches[1] }
if ($rc -match 'VALUE\s+"ProductName",\s*"([^"]*)"') { $dataProduct = $Matches[1] }

# --- Inno Setup compiler -----------------------------------------------------------
function Find-Iscc {
    if ($Iscc) { if (Test-Path $Iscc) { return (Resolve-Path $Iscc).Path } else { Fail "ISCC not found at $Iscc" } }
    if ($env:ISCC -and (Test-Path $env:ISCC)) { return $env:ISCC }
    $cmd = Get-Command iscc.exe -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        (Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:ProgramFiles 'Inno Setup 6\ISCC.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Inno Setup 6\ISCC.exe')
    )
    foreach ($key in @(
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1',
            'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Inno Setup 6_is1')) {
        $props = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if ($props -and $props.PSObject.Properties['InstallLocation'] -and $props.InstallLocation) {
            $candidates += (Join-Path $props.InstallLocation 'ISCC.exe')
        }
    }
    foreach ($c in $candidates) { if ($c -and (Test-Path $c)) { return $c } }
    Fail 'ISCC.exe (Inno Setup 6) not found. Install it with "winget install JRSoftware.InnoSetup" or "choco install innosetup -y", or pass -Iscc <path>.'
}
$isccExe = Find-Iscc
Write-Ok "Inno Setup compiler: $isccExe"

$outDir = Join-Path $Root $OutputDir
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$isccArgs = @(
    "/DAppVersion=$version",
    "/DAppVersionNumeric=$numericVersion",
    "/DSourceDir=$stage",
    "/DOutputDir=$outDir",
    "/DDataCompany=$dataCompany",
    "/DDataProduct=$dataProduct"
)
if ($SignCommand) {
    $isccArgs += "/Sfermatasign=$SignCommand"
    $isccArgs += '/DSignTool=fermatasign'
} else {
    Write-Warn 'setup.exe is NOT code-signed (no -SignCommand): Windows SmartScreen will warn users. See docs\RELEASING.md.'
}
$isccArgs += (Join-Path $Root 'packaging\windows\fermata.iss')

Write-Step 'Compiling the installer'
& $isccExe @isccArgs
if ($LASTEXITCODE -ne 0) { Fail "ISCC failed (exit $LASTEXITCODE)" }

$setup = Join-Path $outDir 'setup.exe'
if (-not (Test-Path $setup)) { Fail "ISCC did not produce $setup" }
$hash = (Get-FileHash -Algorithm SHA256 -Path $setup).Hash.ToLowerInvariant()
$sizeMb = [math]::Round((Get-Item $setup).Length / 1MB, 1)
Write-Step "Done: $setup ($sizeMb MB)"
Write-Host "    sha256 $hash"
