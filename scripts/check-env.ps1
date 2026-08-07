$ErrorActionPreference = "SilentlyContinue"

function Write-Check {
    param(
        [string]$Name,
        [bool]$Ok,
        [string]$Detail = ""
    )

    $status = if ($Ok) { "OK" } else { "MISSING" }
    "{0,-28} {1,-8} {2}" -f $Name, $status, $Detail
}

function Find-FirstFile {
    param([string[]]$Paths)

    foreach ($path in $Paths) {
        if (Test-Path $path) {
            return (Resolve-Path $path).Path
        }
    }

    return $null
}

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
$vsInstall = $null
if (Test-Path $vswhere) {
    $vsInstall = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
}

$msbuildCandidates = @()
if ($vsInstall) {
    $msbuildCandidates += Join-Path $vsInstall "MSBuild\Current\Bin\MSBuild.exe"
}
$msbuildCandidates += "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe"
$msbuildCandidates += "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe"
$msbuild = Find-FirstFile $msbuildCandidates

$kitsRoot = "${env:ProgramFiles(x86)}\Windows Kits\10"
$kitBins = @(Get-ChildItem (Join-Path $kitsRoot "bin") -Directory |
    Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
    Sort-Object Name -Descending)
$latestKitBin = if ($kitBins.Count -gt 0) { $kitBins[0].FullName } else { $null }

$signtool = if ($latestKitBin) { Find-FirstFile @((Join-Path $latestKitBin "x64\signtool.exe")) } else { $null }
$inf2cat = if ($latestKitBin) { Find-FirstFile @(
    (Join-Path $latestKitBin "x64\inf2cat.exe"),
    (Join-Path $latestKitBin "x86\inf2cat.exe")
) } else { $null }
$stampinf = if ($latestKitBin) { Find-FirstFile @((Join-Path $latestKitBin "x64\stampinf.exe")) } else { $null }

$wdkProps = Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\build" -Recurse -Include "*.props","*.targets" | Select-Object -First 1
$wdkToolset = Get-ChildItem "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022" -Recurse -Directory -Filter "WindowsKernelModeDriver10.0" | Select-Object -First 1
$spectreLib = Get-ChildItem "${env:ProgramFiles}\Microsoft Visual Studio\2022","${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022" -Recurse -Filter "vcruntime.lib" |
    Where-Object { $_.FullName -match "\\lib\\spectre\\x64\\" } |
    Select-Object -First 1
$vcTargets = if ($vsInstall) { Join-Path $vsInstall "MSBuild\Microsoft\VC" } else { $null }

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Host "Windows Driver Development Environment"
Write-Host ""
Write-Check "Administrator shell" $isAdmin ($(if ($isAdmin) { "required for install/start/testsigning" } else { "open PowerShell as Administrator for driver install/start" }))
Write-Check "Visual Studio C++ tools" ([bool]$vsInstall) $vsInstall
Write-Check "MSBuild" ([bool]$msbuild) $msbuild
Write-Check "Windows Kits root" (Test-Path $kitsRoot) $kitsRoot
Write-Check "WDK MSBuild props" ([bool]$wdkProps) ($(if ($wdkProps) { $wdkProps.FullName } else { "install Windows Driver Kit" }))
Write-Check "WDK VS toolset" ([bool]$wdkToolset) ($(if ($wdkToolset) { $wdkToolset.FullName } else { "install Component.Microsoft.Windows.DriverKit.BuildTools from elevated PowerShell" }))
Write-Check "Spectre x64 libs" ([bool]$spectreLib) ($(if ($spectreLib) { $spectreLib.FullName } else { "install Microsoft.VisualStudio.Component.VC.14.44.17.14.x86.x64.Spectre" }))
Write-Check "signtool.exe" ([bool]$signtool) $signtool
Write-Check "inf2cat.exe" ([bool]$inf2cat) $inf2cat
Write-Check "stampinf.exe" ([bool]$stampinf) $stampinf
Write-Check "pnputil.exe" ([bool](Get-Command pnputil.exe)) "built into Windows"
Write-Check "bcdedit.exe" ([bool](Get-Command bcdedit.exe)) "built into Windows"

Write-Host ""
Write-Host "Recommended install commands, if anything above is missing:"
Write-Host "winget install --id Microsoft.VisualStudio.2022.BuildTools --exact --accept-package-agreements --accept-source-agreements --override `"--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended`""
Write-Host "winget install --id Microsoft.WindowsWDK.10.0.26100 --exact --accept-package-agreements --accept-source-agreements"
Write-Host "& `"${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe`" modify --installPath `"${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools`" --add Component.Microsoft.Windows.DriverKit.BuildTools --passive --norestart --installWhileDownloading"
Write-Host "& `"${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\setup.exe`" modify --installPath `"${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools`" --add Microsoft.VisualStudio.Component.VC.14.44.17.14.x86.x64.Spectre --passive --norestart --installWhileDownloading"
