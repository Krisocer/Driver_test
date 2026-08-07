param(
    [string]$DriverPath = "$PSScriptRoot\..\x64\Debug\MyStarterDriver.sys",
    [string]$CatalogPath = "$PSScriptRoot\..\x64\Debug\MyStarterDriver\MyStarterDriver.cat",
    [string]$CertSubject = "CN=MyStarterDriver Test Certificate"
)

$ErrorActionPreference = "Stop"

function Find-SignTool {
    $kitsRoot = "${env:ProgramFiles(x86)}\Windows Kits\10\bin"
    $versions = Get-ChildItem $kitsRoot -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
        Sort-Object Name -Descending

    foreach ($version in $versions) {
        $candidate = Join-Path $version.FullName "x64\signtool.exe"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    throw "signtool.exe not found. Install Windows SDK/WDK."
}

$filesToSign = @()
if (Test-Path $DriverPath) {
    $filesToSign += (Resolve-Path $DriverPath).Path
}
if (Test-Path $CatalogPath) {
    $filesToSign += (Resolve-Path $CatalogPath).Path
}
if ($filesToSign.Count -eq 0) {
    throw "No driver or catalog files found to sign. Build first."
}
$cert = Get-ChildItem Cert:\CurrentUser\My |
    Where-Object { $_.Subject -eq $CertSubject -and $_.HasPrivateKey } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1

if (!$cert) {
    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject $CertSubject `
        -CertStoreLocation Cert:\CurrentUser\My `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddYears(3)
}

$signtool = Find-SignTool
& $signtool sign /v /fd SHA256 /sha1 $cert.Thumbprint $filesToSign
if ($LASTEXITCODE -ne 0) {
    throw "signtool.exe failed with exit code $LASTEXITCODE."
}
