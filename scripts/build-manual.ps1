param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug",

    [ValidateSet("x64")]
    [string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

function Get-VsInstall {
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    $vsInstall = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if (!$vsInstall) {
        throw "Visual Studio C++ Build Tools not found."
    }

    return $vsInstall
}

function Get-LatestMsvcTools {
    param([string]$VsInstall)

    $toolsRoot = Join-Path $VsInstall "VC\Tools\MSVC"
    $versions = Get-ChildItem $toolsRoot -Directory | Sort-Object Name -Descending
    if ($versions.Count -eq 0) {
        throw "MSVC tools directory not found."
    }

    return $versions[0].FullName
}

function Get-LatestKitVersion {
    $includeRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\Include"
    $versions = Get-ChildItem $includeRoot -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
        Sort-Object Name -Descending

    if ($versions.Count -eq 0) {
        throw "Windows Kit include directory not found."
    }

    return $versions[0].Name
}

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$outDir = Join-Path $root "$Platform\$Configuration"
$objDir = Join-Path $outDir "obj"
New-Item -ItemType Directory -Force -Path $objDir | Out-Null

$vsInstall = Get-VsInstall
$msvcTools = Get-LatestMsvcTools $vsInstall
$cl = Join-Path $msvcTools "bin\Hostx64\x64\cl.exe"
$link = Join-Path $msvcTools "bin\Hostx64\x64\link.exe"

if (!(Test-Path $cl)) {
    throw "cl.exe not found at $cl."
}

if (!(Test-Path $link)) {
    throw "link.exe not found at $link."
}

$kitVersion = Get-LatestKitVersion
$kitRoot = "${env:ProgramFiles(x86)}\Windows Kits\10"
$kmInclude = Join-Path $kitRoot "Include\$kitVersion\km"
$sharedInclude = Join-Path $kitRoot "Include\$kitVersion\shared"
$ucrtInclude = Join-Path $kitRoot "Include\$kitVersion\ucrt"
$kmLib = Join-Path $kitRoot "Lib\$kitVersion\km\$Platform"
$msvcInclude = Join-Path $msvcTools "include"

$commonDefines = @(
    "/D_AMD64_",
    "/DAMD64",
    "/D_WIN64",
    "/DWINVER=0x0A00",
    "/D_WIN32_WINNT=0x0A00",
    "/DNTDDI_VERSION=0x0A000000",
    "/DPOOL_NX_OPTIN=1"
)

$debugFlags = if ($Configuration -eq "Debug") { @("/Zi", "/Od") } else { @("/O2") }

& $cl /nologo /c /kernel /GS /W4 /WX @debugFlags @commonDefines "/Fd$outDir\MyStarterDriver.pdb" `
    "/I$root\include" "/I$kmInclude" "/I$sharedInclude" "/I$ucrtInclude" "/I$msvcInclude" `
    "$root\src\driver.c" "/Fo$objDir\driver.obj"
if ($LASTEXITCODE -ne 0) {
    throw "cl.exe failed with exit code $LASTEXITCODE."
}

& $link /nologo /driver /kernel /machine:x64 /subsystem:native /entry:DriverEntry `
    "/libpath:$kmLib" `
    "/out:$outDir\MyStarterDriver.sys" `
    "$objDir\driver.obj" ntoskrnl.lib hal.lib
if ($LASTEXITCODE -ne 0) {
    throw "link.exe failed with exit code $LASTEXITCODE."
}

Write-Host "Built $outDir\MyStarterDriver.sys"
