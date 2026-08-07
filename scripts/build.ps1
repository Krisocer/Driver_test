param(
    [ValidateSet("Debug", "Release")]
    [string]$Configuration = "Debug",

    [ValidateSet("x64")]
    [string]$Platform = "x64"
)

$ErrorActionPreference = "Stop"

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (!(Test-Path $vswhere)) {
    throw "vswhere.exe not found. Install Visual Studio Build Tools 2022 first."
}

$vsInstall = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (!$vsInstall) {
    throw "Visual Studio C++ Build Tools not found."
}

$msbuild = Join-Path $vsInstall "MSBuild\Current\Bin\MSBuild.exe"
if (!(Test-Path $msbuild)) {
    throw "MSBuild.exe not found at $msbuild."
}

& $msbuild "$PSScriptRoot\..\MyStarterDriver.vcxproj" `
    "/p:Configuration=$Configuration" `
    "/p:Platform=$Platform" `
    /m
