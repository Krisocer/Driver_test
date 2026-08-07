param(
    [ValidateSet("install", "start", "stop", "remove", "status")]
    [string]$Action = "status",

    [string]$DriverPath = "$PSScriptRoot\..\x64\Debug\MyStarterDriver.sys",
    [string]$ServiceName = "MyStarterDriver"
)

$ErrorActionPreference = "Stop"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (!$isAdmin) {
    throw "Open PowerShell as Administrator to manage a kernel driver service."
}

$resolvedDriver = Resolve-Path $DriverPath

switch ($Action) {
    "install" {
        & sc.exe create $ServiceName type= kernel start= demand binPath= "$resolvedDriver"
        if ($LASTEXITCODE -ne 0) {
            throw "sc create failed with exit code $LASTEXITCODE."
        }
    }
    "start" {
        & sc.exe start $ServiceName
        if ($LASTEXITCODE -ne 0) {
            throw "sc start failed with exit code $LASTEXITCODE."
        }
    }
    "stop" {
        & sc.exe stop $ServiceName
    }
    "remove" {
        & sc.exe delete $ServiceName
    }
    "status" {
        & sc.exe query $ServiceName
    }
}
