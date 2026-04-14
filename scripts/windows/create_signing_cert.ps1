param(
  [string]$CertName = "KhataManagementCodeSign",
  [string]$Publisher = "CN=Saari Technologies",
  [string]$Password = "ChangeThisPassword123!"
)

$ErrorActionPreference = "Stop"

$outDir = Join-Path $PSScriptRoot "cert-output"
New-Item -Path $outDir -ItemType Directory -Force | Out-Null

$cert = New-SelfSignedCertificate `
  -Type Custom `
  -Subject $Publisher `
  -KeyUsage DigitalSignature `
  -FriendlyName $CertName `
  -CertStoreLocation "Cert:\CurrentUser\My" `
  -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3") `
  -NotAfter (Get-Date).AddYears(5)

$securePassword = ConvertTo-SecureString -String $Password -Force -AsPlainText
$pfxPath = Join-Path $outDir "$CertName.pfx"
$cerPath = Join-Path $outDir "$CertName.cer"

Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePassword | Out-Null
Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null

$pfxBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($pfxPath))
$cerBase64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($cerPath))

$pfxB64Path = Join-Path $outDir "$CertName.pfx.base64.txt"
$cerB64Path = Join-Path $outDir "$CertName.cer.base64.txt"
$pwdPath = Join-Path $outDir "$CertName.password.txt"

Set-Content -Path $pfxB64Path -Value $pfxBase64 -NoNewline
Set-Content -Path $cerB64Path -Value $cerBase64 -NoNewline
Set-Content -Path $pwdPath -Value $Password -NoNewline

Write-Host "Created certificate files:"
Write-Host " - $pfxPath"
Write-Host " - $cerPath"
Write-Host ""
Write-Host "Use these files for GitHub Secrets:"
Write-Host " - WIN_CERT_PFX_BASE64 : $pfxB64Path"
Write-Host " - WIN_CERT_CER_BASE64 : $cerB64Path"
Write-Host " - WIN_CERT_PASSWORD   : $pwdPath"
