param([int]$Port = 5050, [switch]$Lan)
$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw 'Node.js 22+ gerekli.' }
if (-not (Test-Path -LiteralPath "$PSScriptRoot\build\web\index.html")) { throw 'Flutter web derlemesi bulunamadi. Install-TradeMind.ps1 ile kurulumu tamamlayin.' }
$env:PORT = [string]$Port
$env:HOST = if ($Lan) { '0.0.0.0' } else { '127.0.0.1' }
Write-Host "TradeMind Flutter: http://localhost:$Port" -ForegroundColor Cyan
& node server/local.cjs
if ($LASTEXITCODE -ne 0) { throw 'TradeMind baslatilamadi. Eski sunucuyu Ctrl+C ile kapatin.' }
